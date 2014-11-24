-- http://serverfault.com/questions/230749/how-to-use-nginx-to-proxy-to-a-host-requiring-authentication
local m           = require 'model_helpers'
local c           = require 'consumer_helpers'
local inspect     = require 'inspect'
local lock        = require 'lock'
local fn          = require 'functional'
local Config      = require 'models.config'

local http_ng      = require 'http_ng'
local async_resty  = require 'http_ng.backend.async_resty'

local http = http_ng.new{ backend = async_resty }

local api_user = os.getenv('SLUG_SENDGRID_USER')
local api_key = os.getenv('SLUG_SENDGRID_KEY')
local from_mail_address = os.getenv('SLUG_FROM_MAIL_ADDR')

local send_mail_sg = function(job)
	local response = http.urlencoded.post(
		'https://api.sendgrid.com/api/mail.send.json',
		{
			api_user = api_user,
			api_key = api_key,
			to = job.to,
			from = from_mail_address,
			subject = job.subject or 'apitools message',
			text = job.body,
		})
	return response.status == 200
end

local send_mail = send_mail_sg

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
	lock.around(mailer.name, function()
		local stand_by = {}
		local job = mailer.next_job()
		local count = 0

		mailer.has_to_act_on = function(job)
			return fn.none(function(x)
				return x == job._id
			end, stand_by)
		end

		while job and count < 5 do
			count = count + 1
			if not job then return end

			if send_mail(job) then
				remove_from_queue('events', job._id)
			else
				table.insert(stand_by, job._id)
			end

			job = mailer.next_job()
		end
	end)
end

mailer.send_mail = send_mail

return mailer
