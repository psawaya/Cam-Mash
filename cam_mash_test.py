from cam_mash_db import CamMashDB

db = CamMashDB()

# db.register_user("john")
db.add_user_match("psawaya","john")
db.add_user_match("psawaya","john",2.0)