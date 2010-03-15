import web

class CamMashDB:
    def __init__(self):
        self.db = web.database(dbn='mysql', user='cam_mash', pw='campwd', db='cam_mash')
        
    def register_user(self,user_id):        
        self.db.insert('users',id=user_id)
        
    def add_user_match(self,user_id1,user_id2,match_weight=1):
        if self.user_exists(user_id1):
            if self.user_exists(user_id2):
                existing_matches = self.db.select("user_matches",dict(u1="psawaya",u2="john"),where="(user1=$u1 and user2=$u2) or (user1=$u2 and user2=$u1)")
                if len(existing_matches) == 0:
                    self.db.insert("user_matches",user1=user_id1, user2=user_id2, weight=match_weight, last_matched=0)
                else:
                    self.db.update("user_matches",where="id=%i" % existing_matches[0].id,weight=match_weight)
            else:
                raise UserDoesNotExistException(user_id2)                
        else:
            raise UserDoesNotExistException(user_id1)
    
    def user_exists(self,user_id):
        retval = self.db.select("users",dict(id=user_id),where="id = $id")
        
        return len(retval) == 1

class UserDoesNotExistException(Exception):
    def __init__(self, user):
        self.user = user
    def __str__(self):
        return "User %s does not exist!" % self.user