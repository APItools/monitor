-- http://serverfault.com/questions/230749/how-to-use-nginx-to-proxy-to-a-host-requiring-authentication
local m           = require 'model_helpers'
local c           = require 'consumer_helpers'
local inspect     = require 'inspect'
local http        = require 'http'
local lock        = require 'resty.lock'
local fn          = require 'functional'
local Config      = require 'models.config'
local resty_http  = require 'resty.http'

local send_mail = function(job)
	local a,b,c =  http.simple(
		{url='https://api.mailgun.net/v2/rgrautest.mailgun.org/messages',
		 method = "POST",
		 body = {
			 from = 'me@rgrautest.mailgun.org',
			 to = job.to,
			 text = job.body,
			 subject = job.subject or 'brainslug message',
		 },
		 headers = {['Authorization'] =
									"Basic " .. ngx.encode_base64("api:key-7ienxqso0z9ohl2un-0m6dbfs3-xgv66"),
								['Host'] =
									'api.mailgun.net',
								['Content-Type'] =
									'application/x-www-form-urlencoded'}
	})
end

local api_user = os.getenv('SLUG_SENDGRID_USER')
local api_key = os.getenv('SLUG_SENDGRID_KEY')
local from_mail_address = os.getenv('SLUG_FROM_MAIL_ADDR')

local send_mail_sg = function(job)

	local body, status, headers =  http.simple{
		url = 'https://api.sendgrid.com/api/mail.send.json',
		method = 'POST',
		body = {
			api_user = api_user,
			api_key = api_key,
			to = job.to,
			from = from_mail_address,
			subject = job.subject or 'apitools message',
			text = job.body,
		},
		headers = {
			Host = 'api.sendgrid.com',
			['Content-Type'] =
				'application/x-www-form-urlencoded'}
	}
	return status == 200
end

send_mail = send_mail_sg

local remove_from_queue = function(queue, id)
  return m.delete(queue, id)
end

local mailer = {
  name = 'mailer',
  has_to_act_on = function(job)
    -- return job.level == 'info'
		return true
  end
}

mailer.next_job = c.next_job(mailer)
mailer.run = function()
	local lock = require 'resty.lock'
	local count = 0
	local stand_by = {}
	mailer.has_to_act_on = function(job)
		return fn.none(function(x)
										return x == job._id
									end,
									stand_by)
	end

	local mail_lock = assert(lock:new('locks'))
	mail_lock:lock(mailer.name)
  local job = mailer.next_job()
	while job and count < 5 do
		count = count + 1
		if not job then
			mail_lock:unlock(mailer.name)
			return
		end

		if send_mail(job) then
			remove_from_queue('events', job._id)
		else
			table.insert(stand_by, job._id)
		end
		job = mailer.next_job()
	end
	mail_lock:unlock(mailer.name)
end

mailer.send_mail = send_mail

mailer.trigger_run = function()
  local client = resty_http.new()
  return client:request_uri('http://' .. Config.localhost .. '/api/mails/send')
end

return mailer
