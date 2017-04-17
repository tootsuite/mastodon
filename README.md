Mastodon
========

[![Build Status](http://img.shields.io/travis/tootsuite/mastodon.svg)][travis]
[![Code Climate](https://img.shields.io/codeclimate/github/tootsuite/mastodon.svg)][code_climate]

[travis]: https://travis-ci.org/tootsuite/mastodon
[code_climate]: https://codeclimate.com/github/tootsuite/mastodon

Mastodon is a free, open-source social network server. A decentralized solution to commercial platforms, it avoids the risks of a single company monopolizing your communication. Anyone can run Mastodon and participate in the social network seamlessly.

An alternative implementation of the GNU social project. Based on ActivityStreams, Webfinger, PubsubHubbub and Salmon.

Click on the screenshot to watch a demo of the UI:

[![Screenshot](https://i.imgur.com/T2q5V65.png)][youtube_demo]

[youtube_demo]: https://www.youtube.com/watch?v=YO1jQ8_rAMU

The project focus is a clean REST API and a good user interface. Ruby on Rails is used for the back-end, while React.js and Redux are used for the dynamic front-end. A static front-end for public resources (profiles and statuses) is also provided.

If you would like, you can [support the development of this project on Patreon][patreon]. Alternatively, you can donate to this BTC address: `17j2g7vpgHhLuXhN4bueZFCvdxxieyRVWd`

[patreon]: https://www.patreon.com/user?u=619786

## Resources

- [List of Mastodon instances](https://github.com/tootsuite/documentation/blob/master/Using-Mastodon/List-of-Mastodon-instances.md)
- [Use this tool to find Twitter friends on Mastodon](https://mastodon-bridge.herokuapp.com)
- [API overview](https://github.com/tootsuite/documentation/blob/master/Using-the-API/API.md)
- [Frequently Asked Questions](https://github.com/tootsuite/documentation/blob/master/Using-Mastodon/FAQ.md)
- [List of apps](https://github.com/tootsuite/documentation/blob/master/Using-Mastodon/Apps.md)

## Features

- **Fully interoperable with GNU social and any OStatus platform**
  Whatever implements Atom feeds, ActivityStreams, Salmon, PubSubHubbub and Webfinger is part of the network
- **Real-time timeline updates**
  See the updates of people you're following appear in real-time in the UI via WebSockets
- **Federated thread resolving**
  If someone you follow replies to a user unknown to the server, the server fetches the full thread so you can view it without leaving the UI
- **Media attachments like images and WebM**
  Upload and view images and WebM videos attached to the updates
- **OAuth2 and a straightforward REST API**
  Mastodon acts as an OAuth2 provider so 3rd party apps can use the API, which is RESTful and simple
- **Background processing for long-running tasks**
  Mastodon tries to be as fast and responsive as possible, so all long-running tasks that can be delegated to background processing, are
- **Deployable via Docker**
  You don't need to mess with dependencies and configuration if you want to try Mastodon, if you have Docker and Docker Compose the deployment is extremely easy

## Checking out

If you want a stable release for production use, you should use tagged releases. To checkout the latest available tagged version:

    git clone https://github.com/tootsuite/mastodon.git
    cd mastodon
    git checkout $(git describe --tags `git rev-list --tags --max-count=1`)

## Configuration

- `LOCAL_DOMAIN` should be the domain/hostname of your instance. This is **absolutely required** as it is used for generating unique IDs for everything federation-related
- `LOCAL_HTTPS` set it to `true` if HTTPS works on your website. This is used to generate canonical URLs, which is also important when generating and parsing federation-related IDs

Consult the example configuration file, `.env.production.sample` for the full list. Among other things you need to set details for the SMTP server you are going to use.

## Requirements

- Ruby
- Node.js
- PostgreSQL
- Redis
- Nginx

### Tasks

- `rake mastodon:media:clear` removes uploads that have not been attached to any status after a while, you would want to run this from a periodic cronjob
- `rake mastodon:push:clear` unsubscribes from PuSH notifications for remote users that have no local followers. You may not want to actually do that, to keep a fuller footprint of the fediverse or in case your users will soon re-follow
- `rake mastodon:push:refresh` re-subscribes PuSH for expiring remote users, this should be run periodically from a cronjob and quite often as the expiration time depends on the particular hub of the remote user
- `rake mastodon:feeds:clear_all` removes all timelines, which forces them to be re-built on the fly next time a user tries to fetch their home/mentions timeline. Only for troubleshooting
- `rake mastodon:feeds:clear` removes timelines of users who haven't signed in lately, which allows to save RAM and improve message distribution. This is required to be run periodically so that when they login again the regeneration process will trigger

## Deployment

There are guides in the documentation repository for [deploying on various platforms](https://github.com/tootsuite/documentation#running-mastodon).

## Contributing

You can open issues for bugs you've found or features you think are missing. You can also submit pull requests to this repository. [Here are the guidelines for code contributions](CONTRIBUTING.md)

**IRC channel**: #mastodon on irc.freenode.net

## Extra credits

- The [Emoji One](https://github.com/Ranks/emojione) pack has been used for the emojis
- The error page image courtesy of [Dopatwo](https://www.youtube.com/user/dopatwo)

![Mastodon error image](https://mastodon.social/oops.png)
