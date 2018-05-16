# Rb1drv

Rb1drv is a Ruby SDK for Microsoft OneDrive service, providing a simple interface to access files inside OneDrive.

Rb1drv allows you to list directories, upload or download files, etc.

To use the command line application, install [`rb1drv-tools`](https://github.com/msg7086/rb1drv-tools) gem instead.

Further functionalities can be added to the library upon requests.

Rb1drv uses the latest Microsoft OAuth2 + Graph API at the time it is written, while there are not many other libraries available for reference (e.g. official OneDrive SDK still uses old OAuth2 API instead of new OAuth2 v2.0 API). Feel free to take this as an unoffical reference implementation and write your own SDK.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rb1drv'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install rb1drv

## Usage

You will have to register a new application on Microsoft Application Registration Portal before using the API.
Read more at [OneDrive API Docs](https://github.com/OneDrive/onedrive-api-docs/blob/live/docs/rest-api/getting-started/graph-oauth.md).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/msg7086/rb1drv.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
