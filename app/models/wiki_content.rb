# Redmine - project management software
# Copyright (C) 2006-2017  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require 'zlib'

class WikiContent < ActiveRecord::Base
  self.locking_column = 'version'
  belongs_to :page, :class_name => 'WikiPage'
  belongs_to :author, :class_name => 'User'
  has_many :versions, :class_name => 'WikiContentVersion', :dependent => :delete_all
  validates_presence_of :text
  validates_length_of :comments, :maximum => 1024, :allow_nil => true

  after_save :create_version
  after_save :send_notification

  scope :without_text, lambda {select(:id, :page_id, :version, :updated_on)}

  def initialize(*args)
    super
    if new_record?
      self.version = 1
    end
  end

  def visible?(user=User.current)
    page.visible?(user)
  end

  def project
    page.project
  end

  def attachments
    page.nil? ? [] : page.attachments
  end

  def notified_users
    project.notified_users.reject {|user| !visible?(user)}
  end

  # Returns the mail addresses of users that should be notified
  def recipients
    notified_users.collect(&:mail)
  end

  # Return true if the content is the current page content
  def current_version?
    true
  end

  # Reverts the record to a previous version
  def revert_to!(version)
    if version.wiki_content_id == id
      update_columns(
          :author_id => version.author_id,
          :text => version.text,
          :comments => version.comments,
          :version => version.version,
          :updated_on => version.updated_on
        ) && reload
    end
  end

  private

  def create_version
    versions << WikiContentVersion.new(attributes.except("id"))
  end

  def send_notification
    # new_record? returns false in after_save callbacks
    if saved_change_to_id?
      if Setting.notified_events.include?('wiki_content_added')
        Mailer.wiki_content_added(self).deliver
      end
    elsif saved_change_to_text?
      if Setting.notified_events.include?('wiki_content_updated')
        Mailer.wiki_content_updated(self).deliver
      end
    end
  end

  # For backward compatibility
  # TODO: remove it in Redmine 5
  Version = WikiContentVersion
end
