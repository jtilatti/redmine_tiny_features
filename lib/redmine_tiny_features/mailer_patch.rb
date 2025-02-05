require_dependency 'mailer'

class Mailer < ActionMailer::Base

  # Sends reminders to issue assignees
  # Available options:
  # * :days     => how many days in the future to remind about (defaults to 7)
  # * :tracker  => id of tracker for filtering issues (defaults to all trackers)
  # * :project  => id or identifier of project to process (defaults to all projects)
  # * :users    => array of assigned user/group ids who should be reminded
  # * :version  => name of target version for filtering issues (defaults to none)
  ####### ADDED BY TINY FEATURES PLUGIN 1/3 #######
  # * :max_delay => ignore older issues: how many days after due date to stop sending reminders (defaults to none)
  def self.reminders(options = {})
    days = options[:days] || 7
    ####### ADDED BY TINY FEATURES PLUGIN 2/3 #######
    max_delay = options[:max_delay] || nil
    project = options[:project] ? Project.find(options[:project]) : nil
    tracker = options[:tracker] ? Tracker.find(options[:tracker]) : nil
    target_version_id = options[:version] ? Version.named(options[:version]).pluck(:id) : nil
    if options[:version] && target_version_id.blank?
      raise ActiveRecord::RecordNotFound.new("Couldn't find Version named #{options[:version]}")
    end

    user_ids = options[:users]

    scope =
      Issue.open.where(
        "#{Issue.table_name}.assigned_to_id IS NOT NULL" \
          " AND #{Project.table_name}.status = #{Project::STATUS_ACTIVE}" \
          " AND #{Issue.table_name}.due_date <= ?", days.day.from_now.to_date
      )
    scope = scope.where(:assigned_to_id => user_ids) if user_ids.present?
    scope = scope.where(:project_id => project.id) if project
    scope = scope.where(:fixed_version_id => target_version_id) if target_version_id.present?
    scope = scope.where(:tracker_id => tracker.id) if tracker
    ####### ADDED BY TINY FEATURES PLUGIN 3/3 #######
    scope = scope.where("#{Issue.table_name}.due_date > ?", max_delay.day.ago.to_date) if max_delay
    issues_by_assignee = scope.includes(:status, :assigned_to, :project, :tracker).
      group_by(&:assigned_to)
    issues_by_assignee.keys.each do |assignee|
      if assignee.is_a?(Group)
        assignee.users.each do |user|
          issues_by_assignee[user] ||= []
          issues_by_assignee[user] += issues_by_assignee[assignee]
        end
      end
    end

    issues_by_assignee.each do |assignee, issues|
      if assignee.is_a?(User) && assignee.active? && issues.present?
        visible_issues = issues.select { |i| i.visible?(assignee) }
        visible_issues.sort! { |a, b| (a.due_date <=> b.due_date).nonzero? || (a.id <=> b.id) }
        reminder(assignee, visible_issues, days).deliver_later if visible_issues.present?
      end
    end
  end

end
