# commit
# author - author of the commit, string
# user - author of the commit, User (NULL if author not registered in system)
class ScmChangeset < ActiveRecord::Base
  belongs_to :user
  belongs_to :scm_project
  belongs_to :task

  has_many :scm_files, :dependent => :destroy

  validates_presence_of :scm_project
  validates_presence_of :author

  accepts_nested_attributes_for :scm_files
  before_create do | changeset |
    if changeset.user_id.nil?
      user= User.find_by_email(changeset.author)
      user= User.find_by_username(changeset.author) if user.nil?
      user= User.find_by_name(changeset.author) if user.nil?
      changeset.user=user
    end
    num= changeset.message.scan(/#(\d+)/).first
    unless (num.nil? or num.first.blank?)
      changeset.task= changeset.scm_project.project.tasks.find_by_task_num(num.first)
    end
  end

  def issue_num
    name = "[#{self.changeset_rev}]"
  end

  def name
    n = "#{self.scm_project.scm_type.upcase} Commit"
    if self.scm_project.scm_type == 'svn'
      n << " (r#{self.changeset_rev})"
    end

    if self.scm_files && self.scm_files.size > 0
      n << " [#{self.scm_files.size} #{self.scm_files.size == 1 ? 'file' : 'files'}]"
    end

    n
  end

  def full_name
    "#{self.scm_project.location}"
  end

  def ScmChangeset.github_parser(payload)
    payload = JSON.parse(payload)
    payload['commits'].collect do |commit|
      changeset= { }
      changeset[:changeset_rev]= commit['id']
      changeset[:scm_files_attributes]=[]
      changeset[:scm_files_attributes] << commit['modified'].collect{ |file| { :path=>file, :state=>:modified } } unless commit['modified'].nil?
      changeset[:scm_files_attributes] << commit['added'].collect{ |file| { :path=>file, :state=>:added } }       unless commit['added'].nil?
      changeset[:scm_files_attributes] << commit['deleted'].collect{ |file| { :path=>file, :state=>:deleted } }   unless commit['deleted'].nil?
      changeset[:scm_files_attributes].flatten!
      changeset[:author] = commit['author']['name']
      changeset[:message] = commit['message']
      changeset[:commit_date] = commit['timestamp']
      changeset
    end
  end
  def ScmChangeset.create_from_web_hook(params)
    scm_project = ScmProject.find_by_secret_key(params[:secret_key])
    if scm_project.nil?
      return false
    end
    if params[:provider] == 'github'
      github_parser(params[:payload]).collect do |changeset|
        scm_changeset=ScmChangeset.new(changeset)
        scm_changeset.scm_project=scm_project
        return false unless scm_changeset.save
        scm_changeset
      end
    else
      return false
    end
  end
end


# == Schema Information
#
# Table name: scm_changesets
#
#  id             :integer(4)      not null, primary key
#  user_id        :integer(4)
#  scm_project_id :integer(4)
#  author         :string(255)
#  changeset_num  :integer(4)
#  commit_date    :datetime
#  changeset_rev  :string(255)
#  message        :text
#
# Indexes
#
#  scm_changesets_commit_date_index  (commit_date)
#  scm_changesets_author_index       (author)
#  fk_scm_changesets_user_id         (user_id)

