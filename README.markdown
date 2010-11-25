
Adam C. 10/21/2010:

This is Kaya Mobile App web page and server v 0.1.
Note: rspec test shows an error "could not open table 'users'" - don't kow why.

Note from the merge from hongzhao fork: 11/24/2010
-------
Wenjing-Chus-MacBook-Pro:kaya_web_app wenjing$ git merge hongz/master
Auto-merging Gemfile
CONFLICT (content): Merge conflict in Gemfile
##Resolved - keep both

Auto-merging Gemfile.lock
Auto-merging app/controllers/meets_controller.rb
CONFLICT (content): Merge conflict in app/controllers/meets_controller.rb
##Keep HEAD
#
Auto-merging app/controllers/mposts_controller.rb
CONFLICT (content): Merge conflict in app/controllers/mposts_controller.rb
##This file has most of the problems.
#user_id should not be in the model - user_id must be derived from User via belongs_to
#lerror must be in the API - this is unusual but will keep it for now, the client will set to fixed 1.0
#user_dev is another added to the API
#will make the minimum to pass tests first - fix the real problems later
Auto-merging app/controllers/users_controller.rb
##There are incorrect modifications but are not used - keep for now
Auto-merging app/helpers/sessions_helper.rb
##This does not seem to have any real difference, maybe a space or newline?
Auto-merging config/routes.rb
CONFLICT (content): Merge conflict in config/routes.rb
#Keep HEAD
Auto-merging spec/controllers/users_controller_spec.rb
CONFLICT (content): Merge conflict in spec/controllers/users_controller_spec.rb
#Kept the test cases although they may not work or be needed
Automatic merge failed; fix conflicts and then commit the result.
=---------

Heroku crashed while starting - unclear what happened. It may not have a clean image.

Fixed syntax problem. But then complained about can't load json.

Migrating stach to 1.9.2
