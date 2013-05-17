#!/usr/bin/env python

import sys
import tweepy
import commands

CONSUMER_KEY = ''
CONSUMER_SECRET = ''
ACCESS_KEY = ''
ACCESS_SECRET = ''

db_file = 'db.twt'

auth = tweepy.OAuthHandler(CONSUMER_KEY, CONSUMER_SECRET)
auth.set_access_token(ACCESS_KEY, ACCESS_SECRET)
api = tweepy.API(auth)

mytimeline = tweepy.Cursor(api.home_timeline).items()
retweets = tweepy.Cursor(api.retweets_of_me).items()

f = open(db_file, 'a')

for status in mytimeline:
    id = status.id
    (s, o) = commands.getstatusoutput ("egrep '^%d$' %s" % (id, db_file))
    if s != 0:
        print "%s: %s" % (status.user.screen_name.encode('utf-8'), status.text.encode('utf-8'))
        print >>f, status.id

"""
for status in retweets:
    print status.from_user
    print "%s: %s" % (status.author.screen_name, status.text)
"""
