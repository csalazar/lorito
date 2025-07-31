# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)

## v0.2
### Added
- Support for subdomains: a subdomain can be assigned to a project.
  When we use a lorito URL such as `domain.tld/aaa/bbb`,
  the application could do anything with it, even removing the path.
  Currently, those requests are captured but end up in the catch-all logs.

  Now, you can assign a subdomain to a project, for instance `p1`.
  When you copy your payloads, the URL will contain `p1.domain.tld` instead of `domain.tld`.
  Then, in logs view any request to `p1.domain.tld` will be associated with the project.

- Improve the logs view to display only the requests associated with projects.
- Highlight logs belonging to projects in logs view
- Add sentry: disabled by default, I added it to catch errors in production.

### Fixed
- Encode URI path containing non-UTF8 characters
- Remove log messages

## v0.1.1
### Added
- Add FetchRemoteIp plug to find real client IP in Cloudflare and Fly.io
- `no_protocol` liquid filter
- docker-compose setup
- Configurable timezone to user settings

### Fixed
- Hide flash info message after 4 seconds
