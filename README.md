# OreOre::Readtwit

This script extract a link url as RSS feed from your Twitter timeline; a.k.a personal Readtwit implementation.

## Usage

This script output a feed file within only an article. If you read feed on feed reader service, you can use Plagger.

    # run as deamon
    ./readtwit &

    # aggregate & publish with plagger
    plagger -c config.yml

    # config.yml example
    plugins:
      - module: Subscription::Config
        config:
          feed:
            - script:/path/to/bin/agg.pl
      - module: CustomFeed::Script
      - module: Publish::Feed
        config:
          format: RSS
          dir: /home/example/Dropbox/Public/
          filename: twittermyfeedlinks.xml
      - module: Notify::Command
        config:
          command: /path/to/bin/rm.pl

## Author

Toru Ozaki <tor.ozaki@gmail.com>

## License

Use it if you can.
This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
