![Mastodon](https://i.imgur.com/NhZc40l.png)
========

[![GitHub release](https://img.shields.io/github/release/mastodon/mastodon.svg)][releases]
[![Build Status](https://img.shields.io/circleci/project/github/mastodon/mastodon.svg)][circleci]
[![Code Climate](https://img.shields.io/codeclimate/maintainability/mastodon/mastodon.svg)][code_climate]
[![Crowdin](https://d322cqt584bo4o.cloudfront.net/mastodon/localized.svg)][crowdin]
[![Docker Pulls](https://img.shields.io/docker/pulls/tootsuite/mastodon.svg)][docker]

[releases]: https://github.com/mastodon/mastodon/releases
[circleci]: https://circleci.com/gh/mastodon/mastodon
[code_climate]: https://codeclimate.com/github/mastodon/mastodon
[crowdin]: https://crowdin.com/project/mastodon
[docker]: https://hub.docker.com/r/tootsuite/mastodon/

Mastodon is a **free, open-source social network server** based on ActivityPub where users can follow friends and discover new ones. On Mastodon, users can publish anything they want: links, pictures, text, video. All Mastodon servers are interoperable as a federated network (users on one server can seamlessly communicate with users from another one, including non-Mastodon software that implements ActivityPub)!

Click below to **learn more** in a video:

[![Screenshot](https://blog.joinmastodon.org/2018/06/why-activitypub-is-the-future/ezgif-2-60f1b00403.gif)][youtube_demo]

[youtube_demo]: https://www.youtube.com/watch?v=IPSbNdBmWKE

## Navigation

- [Project homepage 🐘](https://joinmastodon.org)
- [Support the development via Patreon][patreon]
- [View sponsors](https://joinmastodon.org/sponsors)
- [Blog](https://blog.joinmastodon.org)
- [Documentation](https://docs.joinmastodon.org)
- [Browse Mastodon servers](https://joinmastodon.org/#getting-started)
- [Browse Mastodon apps](https://joinmastodon.org/apps)

[patreon]: https://www.patreon.com/mastodon

## Features

<img src="https://docs.joinmastodon.org/elephant.svg" align="right" width="30%" />

**No vendor lock-in: Fully interoperable with any conforming platform**

It doesn't have to be Mastodon, whatever implements ActivityPub is part of the social network! [Learn more](https://blog.joinmastodon.org/2018/06/why-activitypub-is-the-future/)

**Real-time, chronological timeline updates**

See the updates of people you're following appear in real-time in the UI via WebSockets. There's a firehose view as well!

**Media attachments like images and short videos**

Upload and view images and WebM/MP4 videos attached to the updates. Videos with no audio track are treated like GIFs; normal videos are looped - like vines!

**Safety and moderation tools**

Private posts, locked accounts, phrase filtering, muting, blocking and all sorts of other features, along with a reporting and moderation system. [Learn more](https://blog.joinmastodon.org/2018/07/cage-the-mastodon/)

**OAuth2 and a straightforward REST API**

Mastodon acts as an OAuth2 provider so 3rd party apps can use the REST and Streaming APIs, resulting in a rich app ecosystem with a lot of choices!

## Deployment

**Tech stack:**

- **Ruby on Rails** powers the REST API and other web pages
- **React.js** and Redux are used for the dynamic parts of the interface
- **Node.js** powers the streaming API

**Requirements:**

- **PostgreSQL** 9.5+
- **Redis** 4+
- **Ruby** 2.5+
- **Node.js** 12+

The repository includes deployment configurations for **Docker and docker-compose**, but also a few specific platforms like **Heroku**, **Scalingo**, and **Nanobox**. The [**stand-alone** installation guide](https://docs.joinmastodon.org/admin/install/) is available in the documentation.

A **Vagrant** configuration is included for development purposes. To use it, complete following steps:

- Install Vagrant and Virtualbox
- Run `vagrant up`
- Run `vagrant ssh -c "cd /vagrant && foreman start"`
- Open `http://mastodon.local` in your browser

## Contributing

Mastodon is **free, open-source software** licensed under **AGPLv3**.

You can open issues for bugs you've found or features you think are missing. You can also submit pull requests to this repository, or submit translations using Crowdin. To get started, take a look at [CONTRIBUTING.md](CONTRIBUTING.md). If your contributions are accepted into Mastodon, you can request to be paid through [our OpenCollective](https://opencollective.com/mastodon).

**IRC channel**: #mastodon on irc.libera.chat

## License

Copyright (C) 2016-2021 Eugen Rochko & other Mastodon contributors (see [AUTHORS.md](AUTHORS.md))

This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License along with this program. If not, see <https://www.gnu.org/licenses/>.
