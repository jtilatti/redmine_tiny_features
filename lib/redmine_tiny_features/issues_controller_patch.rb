require_dependency 'issues_controller'

class IssuesController

  append_before_action :find_optional_project_for_new_issue, :only => [:new]
  skip_before_action :authorize, :only => [:render_form_by_ajax, :switch_display_mode]

  def render_form_by_ajax
    @issue = Issue.find(params[:id])

    return unless @issue.editable?
    return unless update_issue_from_params

    render json: { html: render_to_string(partial: 'edit') }

  end

  def switch_display_mode
    new_mode = User.current.issue_display_mode == User::BY_STATUS ? User::BY_PRIORITY : User::BY_STATUS
    User.current.update_attribute(:issue_display_mode, new_mode)
    redirect_to params[:path]
  end

  private

  def find_optional_project_for_new_issue
    if request.format.html?
      if @project.nil? && Setting["plugin_redmine_tiny_features"]["default_project"].present?
        default_project = Project.where(id: Setting["plugin_redmine_tiny_features"]["default_project"]).first
        if @issue.project == @issue.allowed_target_projects.first && default_project.present?
          @issue.project = default_project
        end
      end
    end
  end

end
