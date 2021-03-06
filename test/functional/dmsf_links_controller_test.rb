# encoding: utf-8
# frozen_string_literal: true
#
# Redmine plugin for Document Management System "Features"
#
# Copyright © 2011-20 Karel Pičman <karel.picman@lbcfree.net>
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

require File.expand_path('../../test_helper', __FILE__)

class DmsfLinksControllerTest < RedmineDmsf::Test::TestCase
  include Redmine::I18n

  fixtures :users, :email_addresses, :projects, :members, :dmsf_files, 
    :dmsf_file_revisions, :dmsf_folders, :dmsf_links, :roles, :member_roles
  
  def setup
    @user_admin = User.find 1
    @user_member = User.find 2
    @user_non_member = User.find 3
    @role_manager = Role.find_by(name: 'Manager')
    assert_not_nil @role_manager
    @role_manager.add_permission! :file_manipulation
    @role_developer = Role.find_by(name: 'Developer')
    assert_not_nil @role_developer
    @role_developer.add_permission! :file_manipulation
    @project1 = Project.find 1
    @project1.enable_module! :dmsf
    @project2 = Project.find 2
    @project2.enable_module! :dmsf    
    @folder1 = DmsfFolder.find 1 # project1/folder1
    @folder2 = DmsfFolder.find 2 # project1/folder1/folder2
    @folder3 = DmsfFolder.find 3 # project2/folder3
    @file1 = DmsfFile.find 1 # project1/file1
    @file2 = DmsfFile.find 2 # project2/file2
    @file4 = DmsfFile.find 4 # project1/folder2/file4
    @file6 = DmsfFile.find 6 # project2/folder3/file6
    @file_link = DmsfLink.find 1
    @request.env['HTTP_REFERER'] = dmsf_folder_path(id: @project1.id, folder_id: @folder1.id)
    @request.session[:user_id] = @user_member.id
    User.current = nil
  end
  
  def test_truth
    assert_kind_of User, @user_admin
    assert_kind_of User, @user_member
    assert_kind_of User, @user_non_member
    assert_kind_of Project, @project1
    assert_kind_of Project, @project2
    assert_kind_of Role, @role_manager
    assert_kind_of Role, @role_developer
    assert_kind_of DmsfFolder, @folder1
    assert_kind_of DmsfFolder, @folder2
    assert_kind_of DmsfFolder, @folder3
    assert_kind_of DmsfFile, @file1
    assert_kind_of DmsfFile, @file2
    assert_kind_of DmsfFile, @file4
    assert_kind_of DmsfFile, @file6
    assert_kind_of DmsfLink, @file_link
  end
  
  def test_authorize_admin    
    @request.session[:user_id] = @user_admin.id
    get :new, params: { project_id: @project1.id }
    assert_response :success
    assert_template 'new'   
  end

  def test_authorize_non_member
    @request.session[:user_id] = @user_non_member.id
    get :new, params: { project_id: @project2.id }
    assert_response :forbidden
  end
    
  def test_authorize_member_ok
    @request.session[:user_id] = @user_member.id
    get :new, params: { project_id: @project1.id }
    assert_response :success
  end
  
  def test_authorize_member_no_module
    # Without the module
    @project1.disable_module!(:dmsf)    
    get :new, params: { project_id: @project1.id }
    assert_response :forbidden    
  end
  
  def test_authorize_forbidden
    # Without permissions
    @project1.enable_module!(:dmsf)
    @role_manager.remove_permission! :file_manipulation
    get :new, params: { project_id: @project1.id }
    assert_response :forbidden    
  end
  
  def test_new    
    get :new, params: { project_id: @project1.id, type: 'link_to'}
    assert_response :success
    assert_select 'label', { text: l(:label_target_project) }
  end

  def test_new_fast_links_enabled
    member = Member.where(user_id: @user_member.id, project_id: @project1.id).first
    assert member
    member.update_attribute :dmsf_fast_links, true
    get :new, params: { project_id: @project1.id, type: 'link_to'}
    assert_response :success
    assert_select 'label', { count: 0, text: l(:label_target_project) }
  end
  
  def test_create_file_link_from_f1
    # 1. File link in a folder from another folder
    assert_difference 'DmsfLink.count', +1 do    
      post :create, params: { dmsf_link: {
        project_id: @project1.id, 
        target_project_id: @project2.id,
        dmsf_folder_id: @folder1.id,
        target_file_id: @file6.id,
        target_folder_id: @folder3.id,
        name: 'file_link',
        type: 'link_from'
      }}
    end    
    assert_redirected_to dmsf_folder_path(id: @project1.id, folder_id: @folder1.id)
  end
  
  def test_create_file_link_from_f2
    # 2. File link in a folder from another root folder
    assert_difference 'DmsfLink.count', +1 do    
      post :create, params: { dmsf_link: {
        project_id: @project1.id, 
        dmsf_folder_id: @folder1.id,
        target_project_id: @project2.id,        
        target_file_id: @file2.id,
        target_folder_id: 'Documents',
        name: 'file_link',
        type: 'link_from'
      }}
    end    
    assert_redirected_to dmsf_folder_path(id: @project1.id, folder_id: @folder1.id)
  end
  
  def test_create_file_link_from_f3
    # 3. File link in a root folder from another folder
    assert_difference 'DmsfLink.count', +1 do    
      post :create, params: { dmsf_link: {
        project_id: @project1.id, 
        target_project_id: @project2.id,        
        target_file_id: @file6.id,
        target_folder_id: @folder3.id,
        name: 'file_link',
        type: 'link_from'
      }}
    end    
    assert_redirected_to dmsf_folder_path(id: @project1.id)
  end
  
  def test_create_file_link_from_f4
    # 4. File link in a root folder from another root folder
    assert_difference 'DmsfLink.count', +1 do    
      post :create, params: { dmsf_link: {
        project_id: @project1.id, 
        target_project_id: @project2.id,        
        target_file_id: @file2.id,        
        name: 'file_link',
        type: 'link_from'
      }}
    end
    assert_redirected_to dmsf_folder_path(id: @project1.id)
  end

  def test_create_folder_link_from_d1
    # 1. Folder link in a folder from another folder
    assert_difference 'DmsfLink.count', +1 do    
      post :create, params: { dmsf_link: {
        project_id: @project1.id, 
        dmsf_folder_id: @folder1.id,
        target_project_id: @project2.id,        
        target_folder_id: @folder3.id,
        name: 'folder_link',
        type: 'link_from'
      }}
    end    
    assert_redirected_to dmsf_folder_path(id: @project1.id, folder_id: @folder1.id)
  end
    
  def test_create_folder_link_from_d2
    # 2. Folder link in a folder from another root folder
    assert_difference 'DmsfLink.count', +1 do    
      post :create, params: { dmsf_link: {
        project_id: @project1.id, 
        dmsf_folder_id: @folder1.id,
        target_project_id: @project2.id,        
        name: 'folder_link',
        type: 'link_from'
      }}
    end    
    assert_redirected_to dmsf_folder_path(id: @project1.id, folder_id: @folder1.id)
  end
    
  def test_create_folder_link_from_d3
    # 3. Folder link in a root folder from another folder
    assert_difference 'DmsfLink.count', +1 do    
      post :create, params: { dmsf_link: {
        project_id: @project1.id,         
        target_project_id: @project2.id,                
        target_folder_id: @folder3.id,
        name: 'folder_link',
        type: 'link_from'
      }}
    end    
    assert_redirected_to dmsf_folder_path(id: @project1.id)
  end
    
  def test_create_folder_link_from_d4
    # 4. Folder link in a root folder from another root folder
    assert_difference 'DmsfLink.count', +1 do    
      post :create, params: { dmsf_link: {
        project_id: @project1.id, 
        target_project_id: @project2.id,                
        name: 'folder_link',
        type: 'link_from'
      }}
    end
    assert_redirected_to dmsf_folder_path(id: @project1.id)
  end
  
  def test_create_file_link_to_f1
    # 1. File link to a root folder from another folder
    assert_difference 'DmsfLink.count', +1 do    
      post :create, params: { dmsf_link: {
        project_id: @project1.id,
        dmsf_file_id: @file1.id,
        target_project_id: @project2.id,
        target_folder_id: @folder3.id,        
        name: 'file_link',
        type: 'link_to'
      }}
    end
    assert_redirected_to dmsf_file_path(@file1)        
  end
    
  def test_create_file_link_to_f2
    # 2. File link to a folder from another folder
    assert_difference 'DmsfLink.count', +1 do    
      post :create, params: { dmsf_link: {
        project_id: @project2.id,         
        dmsf_folder_id: @folder3.id,
        target_project_id: @project1.id,
        target_folder_id: @folder1.id,
        dmsf_file_id: @file6.id,
        name: 'file_link',
        type: 'link_to'
      }}
    end
    assert_redirected_to dmsf_file_path(@file6)
  end
    
  def test_create_file_link_to_f3
    # 3. File link to a root folder from another root folder
    assert_difference 'DmsfLink.count', +1 do    
      post :create, params: { dmsf_link: {
        project_id: @project2.id,                 
        target_project_id: @project1.id,        
        dmsf_file_id: @file6.id,
        name: 'file_link',
        type: 'link_to'
      }}
    end
    assert_redirected_to dmsf_file_path(@file6)
  end
    
  def test_create_file_link_to_f4
    # 4. File link to a folder from another root folder
    assert_difference 'DmsfLink.count', +1 do    
      post :create, params: { dmsf_link: {
        project_id: @project2.id,         
        dmsf_folder_id: @folder3.id,
        target_project_id: @project1.id,        
        dmsf_file_id: @file6.id,
        name: 'file_link',
        type: 'link_to'
      }}
    end
    assert_redirected_to dmsf_file_path(@file6)
  end
  
  def test_create_external_link_from
    assert_difference 'DmsfLink.count', +1 do    
      post :create, params: { dmsf_link: {
        project_id: @project1.id,        
        target_project_id: @project1.id,        
        name: 'file_link',
        external_link: 'true',
        type: 'link_from'        
      }}
    end
    assert_redirected_to dmsf_folder_path(id: @project1.id)
  end
  
  def test_create_folder_link_to_f1
    # 1. Folder link to a root folder
    assert_difference 'DmsfLink.count', +1 do    
      post :create, params: { dmsf_link: {
        project_id: @project1.id,         
        dmsf_folder_id: @folder1.id,
        target_project_id: @project2.id,        
        name: 'folder_link',
        type: 'link_to'
      }}
    end
    assert_redirected_to dmsf_folder_path(id: @project1, folder_id: @folder1.dmsf_folder)
  end
  
  def test_create_folder_link_to_f2
    # 2. Folder link to a folder
    assert_difference 'DmsfLink.count', +1 do    
      post :create, params: { dmsf_link: {
        project_id: @project1.id,         
        dmsf_folder_id: @folder1.id,
        target_project_id: @project2.id,
        target_folder_id: @folder3.id,        
        name: 'folder_link',
        type: 'link_to'
      }}
    end
    assert_redirected_to dmsf_folder_path(id: @project1, folder_id: @folder1.dmsf_folder)
  end
  
  def test_destroy          
    assert_difference 'DmsfLink.visible.count', -1 do
      delete :destroy, params: { project_id: @project1.id, id: @file_link.id }
    end
    assert_redirected_to dmsf_folder_path(id: @project1.id, folder_id: @folder1.id)
  end
  
  def test_restore_forbidden
    # Missing permissions
    @request.env['HTTP_REFERER'] = trash_dmsf_path(id: @project1.id)        
    @role_manager.remove_permission! :file_manipulation
    get :restore, params: { project_id: @project1.id, id: @file_link.id }
    assert_response :forbidden
  end
    
  def test_restore_ok
    # Permissions OK
    @request.env['HTTP_REFERER'] = trash_dmsf_path(id: @project1.id)        
    @role_manager.add_permission! :file_manipulation
    get :restore, params: { project_id: @project1.id, id: @file_link.id }
    assert_response :redirect
  end

end