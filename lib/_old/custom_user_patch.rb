module Custom
  module UserPatch
    def self.included(base)
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)
      base.class_eval do
        unloadable
        #alias_method_chain :try_to_login, :custom_error_message
        # additional account status
        const_set(:STATUS_ARCHIVED, 4)
        named_scope :active_and_archived, :conditions => "#{User.table_name}.status = #{User::STATUS_ACTIVE} or #{User.table_name}.status = #{User::STATUS_ARCHIVED}"
      end
    end
    
    module ClassMethods
      # Returns the user that matches provided login and password, or nil
      def try_to_login_with_custom_error_message(login, password)
        # Make sure no one can sign in with an empty password
        return nil if password.to_s.empty?
        user = find(:first, :conditions => ["login=?", login])
        if user
          # user is already in local database
          return user if !user.active?
          if user.auth_source
            # user has an external authentication method
            return nil unless user.auth_source.authenticate(login, password)
          else
            # authentication with local password
            return nil unless User.hash_password(password) == user.hashed_password
          end
        else
          # user is not yet registered, try to authenticate with available sources
          attrs = AuthSource.authenticate(login, password)
          if attrs
            user = new(*attrs)
            user.login = login
            user.language = Setting.default_language
            if user.save
              user.reload
              logger.info("User '#{user.login}' created from the LDAP") if logger
            end
          end
        end
        user.update_attribute(:last_login_on, Time.now) if user && !user.new_record?
        user
      rescue => text
        raise text
      end
    end
    
    module InstanceMethods
      def archived?
        status == User::STATUS_ARCHIVED
      end
    end
  end
end
