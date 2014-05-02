:warning: *Use of this software is subject to important terms and conditions as set forth in the License file* :warning:

## Samson

### What?

A web interface to Zendesk's deployments.

### How?

It ensures the repository is up-to-date, and then executes the commands associated with that project and stage.

Streaming is done through a [controller](app/controllers/streams_controller.rb) that allows both web access and curl access. A [subscriber thread](config/initializers/instrumentation.rb) is created on startup.

#### Config:

1. We need to add a database configuration yaml file with your credentials.
2. Set up an authentication method in `.env` - at least one of Zendesk (`CLIENT_SECRET` and `ZENDESK_URL`)and GitHub (`GITHUB_CLIENT_ID` and `GITHUB_CLIENT_SECRET`).


```bash
cp config/database.<MS_ACCESS>.yml.example config/database.yml # replace <MS_ACCESS> by your favourite database from mysql, postgres or sqlite
subl config/database.yml # put your credentials in
script/bootstrap

# fill in .env with a few variables
# [SESSION]

#
# [REQUIRED]
# SECRET_TOKEN for rails, can be generated with `bundle exec rake secret`.
#
# GITHUB_ORGANIZATION (eg. zendesk)
# GITHUB_CLIENT_ID and GITHUB_CLIENT_SECRET are for GitHub auth
# and can be obtained by creating a new Github Application
# See: https://github.com/settings/applications
# https://developer.github.com/v3/oauth/
# GITHUB_TOKEN is a personal GitHub token. You can generate a new
# at https://github.com/settings/applications - it gets assigned to GITHUB_TOKEN.
#
# [OPTIONAL]
# GITHUB_ADMIN_TEAM (team members automatically become Samson admins)
# GITHUB_DEPLOY_TEAM (team members automatically become Samson deployers)
#
# Authentication is also possible using Zendesk, in that case set your
# Zendesk token to CLIENT_SECRET and your URL to ZENDESK_URL in .env.
# Make one at https://<subdomain>.zendesk.com/agent/#/admin/api -> OAuth clients.
# Set the UID to 'deployment' and the redirect URL to http://localhost:9080/auth/zendesk/callback
#
# You may fill in NEWRELIC_API_KEY using the instructions below if you would like a dynamic chart of response time and throughput during deploys.
# https://docs.newrelic.com/docs/features/getting-started-with-the-new-relic-rest-api#setup
```

#### To run:

```bash
bundle exec puma -C config/puma.rb
```

The website runs at `localhost:9080` by default.

#### Admin user

Once you've successfully logged in via oauth, your first user automatically becomes an admin.

#### Notes

\* Currently `deploy` is hardcoded as the deploy user, you will want
to change it to your own for testing.

[1]: https://github.com/rails/rails/issues/10989

#### CI support

Samson can be integrated with CI services through webhooks.
You can find a link to webhook on every project page.
There are links on webhook pages that you will want to add to your project settings on your CI service.
Set up your webhooks and the deployment process can be automated.

##### Process

-> Push to branch(e.g. master)
-> CI validation
-> CI makes webhook call
-> Samson receives webhook call
-> Samson checks if validation is passed
-> Deploy if passed / do nothing if failed

##### Supported services

* Travis
    * You can add a webhook notification to the .travis.yml file per project
* Semaphore
    * Semaphore has webhook per project settings
    * Add webhook link to your semaphore project
* Tddium
    * Tddium only has webhook per organisation setting
    * However you can have multiple webhooks per organisation
    * Add all webhooks to your organisation
    * Samson will match url to see if the webhook call is for the correct project

Skip a deploy:

Add "[deploy skip]" to your commit message, and Samson will ignore the webhook
from CI.

#### Continuous Delivery & Releases

In addition to automatically deploying passing commits to various stages, you
can also create an automated continuous delivery pipeline. By setting a *release
branch*, each new passing commit on that branch will cause a new release, with a
automatically incrementing version number. The commit will be tagged with the
version number, e.g. `v42`, and the release will appear in Samson.

Any stage can be configured to automatically deploy new releases. For instance,
you might want each new release to be deployed to your staging environment
automatically.

### Team

Core team is @steved555, @dasch, @jwswj, @halcyonCorsair, @princemaple & @sandlerr.
