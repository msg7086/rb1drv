# Rb1drv

[![Build Status](https://travis-ci.org/msg7086/rb1drv.svg?branch=master)](https://travis-ci.org/msg7086/rb1drv)

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

    od = OneDrive.new('a2b3c4d5-your-app-id', 'C8V3{your-app-secret(', 'https://your-callback/url')

To start using `OneDrive` library, instanciate the class with your application information.

---

    od.root
    od.get('/Folder1')
    od.get('/File1.avi')

Use `OneDrive#root` or `OneDrive#get` to get a drive item.

---

    od.root.children
    od.root.children.grep(OneDriveDir)

Use `OneDriveDir#children` to get contents of a directory.

---

    od.get('/File1.avi').save_as('/tmp/test.avi', overwrite: true) do |event, stat|
      puts "Downloaded #{stat[:progress]} of #{stat[:total]}" if event == :progress
    end

Use `OneDriveFile#save_as` to download a file.

---

    od.get('/Folder1').upload('/tmp/test.avi', overwrite: true, target_name: 'party.avi') do |event, stat|
      puts "Uploading #{stat[:progress]} of #{stat[:total]} for segment #{stat[:from]}-#{stat[:to]}" if event == :progress
      puts "Uploaded segment #{stat[:from]}-#{stat[:to]}" if event == :finish_segment
    end

Use `OneDriveDir#upload` to upload a file to target directory.

By default `OneDriveDir` cache `#get` and `#children` requests, but you can disable it globally

```ruby
od
folder = od.folder('/my_folder') # will be OneDriveDir instance
folder.get('some_file.mp3') # will make API request
folder.get('some_file.mp3') # will make API request again
```

or locally for particular `OneDriveDir` instance

```ruby
folder = od.folder('/my_folder') # will be OneDriveDir instance
folder.skip_cache = true
folder.get('some_file.mp3') # will make API request
folder.get('some_file.mp3') # will make API request again
```

Also you can clear cache for particular `OneDriveDir` instance using `#clear_cache!` method

```ruby
folder = od.folder('/my_folder') # will be OneDriveDir instance
folder.get('some_file.mp3') # will make API request
folder.get('some_file.mp3') # will return cached object
folder.clear_cache!
folder.get('some_file.mp3') # will make API request again
```

by default `OneDrive` returns hash with error when request failed
(except file not found - in that case it returns instance of `OneDrive404`)

but you can force library to raise exception instead

```ruby
Rb1drv.raise_on_failed_request = true
begin
  od.get('/invalid:folder2')
rescue Rb1drv::Errors::ApiError => e
  puts e.message # "Resource not found for the segment 'rootfolder2'."
  puts e.code # "BadRequest"
end
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/msg7086/rb1drv.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
