## `kensa create my_addon --template sinatra`

this repository is a sinatra template application for use with the 
Heroku <a href="http://github.com/heroku/kensa">kensa</a> gem

dependencies:

    > gem install kensa
    > gem install foreman

clone it via:

    > kensa create my_addon --template sinatra
    > cd my_addon
    > bundle install
    > foreman start

In a new window: 

    > cd my_addon
    > kensa test provision
    > kensa sso 1

And you should be in a Heroku Single Sign On sesion for your brand new addon! 

## Current status: 
- deprovision - working
- provision   - working
- planchange  - working
- GET SSO     - working
- POST SSO    - working
