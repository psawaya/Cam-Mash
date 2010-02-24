from vendor import web
from google.appengine.ext import db

class ChatUser(db.Model):
    chat_id = db.StringProperty(required=True,indexed=True)
    last_seen = db.DateTimeProperty(required=True,auto_now=True)

class UserTag(db.Model):
    tag_name = db.StringProperty(required=True,indexed=True)
    chat_user = db.ReferenceProperty(ChatUser)