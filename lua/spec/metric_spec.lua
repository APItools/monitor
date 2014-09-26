local Metric = require 'models.metric'

describe("Metric", function()

  local now,
        one_h_ago, compacted_one_h_ago, also_one_h_ago,
        yesterday, compacted_yesterday, also_yesterday,
        last_week, compacted_last_week, also_last_week,
        last_month, compacted_last_month, also_last_month

  local minute = 60
  local hour   = 60*minute
  local day    = 24*hour
  local week   = 7*day
  local month  = 30*day

  before_each(function()
    Metric:delete_collection()

    now = 0
    ngx.now = function() return now end

    one_h_ago             = ngx.now() - 65 * minute
    compacted_one_h_ago   = Metric:get_compacted_bucket(one_h_ago)
    also_one_h_ago        = compacted_one_h_ago + minute + 1
    yesterday             = ngx.now() - 25 * hour
    compacted_yesterday   = Metric:get_compacted_bucket(yesterday)
    also_yesterday        = compacted_yesterday + 11 * minute
    last_week             = ngx.now() - 8 * day
    compacted_last_week   = Metric:get_compacted_bucket(last_week)
    also_last_week        = compacted_last_week + 2 * hour
    last_month            = ngx.now() - 31 * day
    compacted_last_month  = Metric:get_compacted_bucket(last_month)
    also_last_month       = compacted_last_month + 2 * hour
  end)

  -- Metric factory
  local function create(attributes)
    attributes = attributes or {}
    return Metric:create({
      _created_at  = attributes._created_at  or ngx.now(),
      ['type']     = attributes['type']      or 'count',
      name         = attributes.name         or 'foo',
      service_id   = attributes.service_id   or 42,
      method       = attributes.method       or 'get',
      generic_path = attributes.generic_path or '/foo/bar',
      status       = attributes.status       or 200,
      projections  = attributes.projections  or {count = 1}
    })
  end

  describe(":compact", function()
    it('leaves the metrics intact if they are from today', function()
      create()
      assert.equal(Metric:count(), 1)
      Metric:compact()
      assert.equal(Metric:count(), 1)
    end)

    it('compacts metrics older than 1 hour into minutes, older than 1 day in to hours, older than 1 week into days, and older than 1 month into weeks', function()
      create() -- today
      assert.equal(Metric:count(), 1)

      for i=1,5 do create({_created_at = one_h_ago + i}) end
      for i=1,5 do create({_created_at = also_one_h_ago + i}) end

      assert.equal(Metric:count(), 11)

      Metric:compact()

      assert.equal(Metric:count(), 3)

      for i=1,5 do create({_created_at=yesterday + i}) end
      for i=1,5 do create({_created_at=also_yesterday + i}) end

      assert.equal(Metric:count(), 13)

      Metric:compact()

      assert.equal(Metric:count(), 4)

      for i=1,5 do create({_created_at=last_week + i}) end
      for i=1,5 do create({_created_at=also_last_week + i}) end

      assert.equal(Metric:count(), 14)

      Metric:compact()
      assert.equal(Metric:count(), 5)


      for i=1,5 do create({_created_at=last_month + i}) end
      for i=1,5 do create({_created_at=also_last_month + i}) end

      assert.equal(Metric:count(), 15)

      Metric:compact()

      assert.equal(Metric:count(), 6)
    end)

    describe('when limiting compacting to a date range', function()
      before_each(function()
        for i=1,5 do create({_created_at = one_h_ago + i}) end
        for i=1,5 do create({_created_at = yesterday }) end
        for i=1,5 do create({_created_at = last_month - i}) end
        assert.equal(Metric:count(), 15)
      end)
      it('does not compact recent metrics when asked to compact old metrics only', function()
        Metric:compact(nil, last_month)
        assert.equal(Metric:count(), 11)
      end)

      it('does not compact old metrics when asked to compact new metrics only', function()
        Metric:compact(one_h_ago, nil)
        assert.equal(Metric:count(), 11)
      end)

      it('does not compact old or new when asked to compact middle metrics only', function()
        local the_day_before_yesterday = yesterday - day
        Metric:compact(the_day_before_yesterday, yesterday)
        assert.equal(Metric:count(), 11)
      end)
    end)
  end)

  describe('a compacted metric', function()
    it('has 1 extra field: granularity', function()
      for i=1,5 do create({_created_at = one_h_ago + i}) end
      Metric:compact()
      local metric = Metric:all()[1]
      assert.equal(60, metric.granularity)
    end)

    it('has the _created_at field set to the start of the compacted bucket', function()
      for i=1,5 do create({_created_at=yesterday + i}) end
      Metric:compact()
      local metric = Metric:all()[1]
      assert.equal(compacted_yesterday, metric._created_at)
    end)

    it('aglutinates the counts on metrics of type "count"', function()
      for i=1,5 do create({_created_at=last_month + i}) end
      Metric:compact()
      local metric = Metric:all()[1]
      assert.same({count = 5}, metric.projections)
    end)

    it('aglutinates the stats of metrics of type "set"', function()
      for i=1,5 do
        create({
          ['type'] = 'set',
          _created_at=last_month + i,
          projections = {
            len = 10,
            min = 2,
            max = 9,
            sum = 50,
            avg = 5,
            p50 = 5,
            p80 = 7,
            p90 = 8,
            p95 = 8,
            p99 = 9
          }
        })
      end
      Metric:compact()
      local metric = Metric:all()[1]
      assert.same(metric.projections, {
        len = 50,
        min = 2,
        max = 9,
        sum = 250,
        avg = 5,
        p50 = 5,
        p80 = 7,
        p90 = 8,
        p95 = 8,
        p99 = 9
      })
    end)
  end)

  describe('a compacted metric made of compacted metrics', function()
    it('still has the correct granularity, _created_at and count', function()
      for i=1,5 do create({_created_at=one_h_ago + i}) end
      for i=1,5 do create({_created_at=also_one_h_ago + i}) end

      Metric:compact()

      now = now + 25*hour

      Metric:compact()

      assert.equal(Metric:count(), 1)

      local metric = Metric:all()[1]
      assert.equal(3600, metric.granularity)
      assert.same({count = 10}, metric.projections)
      assert.equal(Metric:get_compacted_bucket(one_h_ago), metric._created_at)
    end)

    it('takes into account the granularity of already compacted metrics', function()
      for i=1,5 do
        create({
          ['type'] = 'set',
          _created_at = one_h_ago + i,
          projections = {
            len = 10,
            min = 2,
            max = 10,
            sum = 50,
            avg = 5,
            p50 = 5,
            p80 = 5,
            p90 = 8,
            p95 = 8,
            p99 = 10
          }
        })
      end

      for i=1,10 do
        create({
          ['type'] = 'set',
          _created_at = also_one_h_ago + i,
          projections = {
            len = 5,
            min = 0,
            max = 5,
            sum = 30,
            avg = 4,
            p50 = 4,
            p80 = 5,
            p90 = 5,
            p95 = 5,
            p99 = 5
          }
        })
      end

      assert.same(15, Metric:count())

      Metric:compact()
      assert.same(2, Metric:count())

      now = now + 25*hour

      Metric:compact()
      assert.same(1, Metric:count())

      local metric = Metric:all()[1]
      assert.same(metric.projections, {
        len = 100,
        min = 0,
        max = 10,
        sum = 550,
        avg = 5.5,
        p50 = 4.5,
        p80 = 5,
        p90 = 6.5,
        p95 = 6.5,
        p99 = 7.5
      })

    end)
  end)

  describe(":get_compacted_bucket", function()
    it("#focus returns same date for very recent dates", function()
      local today = ngx.now()
      assert.same({now}, {Metric:get_compacted_bucket(today)})
    end)
    it("compacts buckets by minutes after the first hour", function()
      local expected_bucket = math.floor(one_h_ago / 60) * 60
      assert.same({expected_bucket, 60}, {Metric:get_compacted_bucket(one_h_ago)})
    end)
    it("compacts buckets by hours after the first day", function()
      local expected_bucket = math.floor(yesterday / hour) * hour
      assert.same({expected_bucket, hour}, {Metric:get_compacted_bucket(yesterday)})
    end)
    it("compacts buckets by days after the first week", function()
      local expected_bucket = math.floor(last_week / day) * day
      assert.same({expected_bucket, day}, {Metric:get_compacted_bucket(last_week)})
    end)
    it("compacts buckets by week after the first month", function()
      local expected_bucket = math.floor(last_month / week) * week
      assert.same({expected_bucket, week}, {Metric:get_compacted_bucket(last_month)})
    end)
  end)

  describe(":delete_collection", function()

    it("deletes all keys", function()
      local redis = require 'concurredis'

      redis.execute(function(red)
        red:flushall()
        assert.same({}, red:keys('jor/metrics/*'))

        local metric = Metric:create({name = 'test'})
        local keys = red:keys('jor/metrics/*')

        Metric:delete_collection()
        local empty_keys = red:keys('jor/metrics/*')
        assert.same({'jor/metrics/next_id'}, empty_keys)
      end)
    end)
  end)
end)
