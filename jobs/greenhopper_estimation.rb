require 'net/http'
require 'json'

rapid_view_id = 0
sprint_id     = 0

# authenticate
http             = Net::HTTP.new('-- YOUR JIRA HOST --', 443)
http.use_ssl     = true
http.verify_mode = OpenSSL::SSL::VERIFY_NONE

request = Net::HTTP::Post.new('/rest/auth/latest/session')
#request.basic_auth('username', 'password')
request.content_type = 'application/json'
request.body = '{"username": "-- YOUR USER --", "password": "-- YOUR PASS --"}'

response = http.request(request);
session  = JSON.parse(response.body)['session']

if session['name'] == 'JSESSIONID'
  session_cookie = {'COOKIE' => 'JSESSIONID=%s' % session['value']}

  # start scheduler
  SCHEDULER.every '30m', :first_in => 0 do
    url = '/rest/greenhopper/1.0/rapid/charts/sprintreport?rapidViewId=%d&sprintId=%d' % [rapid_view_id, sprint_id]

    request = Net::HTTP::Get.new(url, session_cookie)
    #request.basic_auth('username', 'password')

    response = http.request(request)
    report   = JSON.parse(response.body)

    if report['contents']
      not_started = 0
      in_progress = 0
      done = 0

      all_issues  = report['contents']['completedIssues']
      all_issues += report['contents']['incompletedIssues']
      all_issues += report['contents']['puntedIssues']

      all_issues.each { |issue|
        next if not issue['estimateStatistic']['statFieldValue']['value']

        issue_value = issue['estimateStatistic']['statFieldValue']['value'].to_i

        case issue['statusName']
        when 'Planned', 'Ready for Testing', 'In Progress'
          in_progress += issue_value
        when 'Closed', 'Resolved'
          done += issue_value
        else
          p('UNMATCHABLE ISSUE:', issue)
        end
      }

      send_event('greenhopper_estimation', {
        sprint: report['sprint']['name'],
        not_started: not_started,
        in_progress: in_progress,
        done: done
      })
    end
  end
end