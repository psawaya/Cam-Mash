import web

from web.db import SQLQuery, SQLParam

from random import randint

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
    
    def get_user_match(self,user_id):
        #Can be implemented in pure SQL: http://dev.mysql.com/tech-resources/articles/rolling_sums_in_mysql.html
        #That said, this could definitely use some cleaning up!
        
        q = SQLQuery(["SELECT sum(weight) as total_weight FROM user_matches WHERE user1 = ", SQLParam(user_id), " OR user2=", SQLParam(user_id)])
        weight_sum = self.db.query(q)[0]['total_weight']
        
        if weight_sum is None: return []
                
        weighted_idx = randint(0,weight_sum-1)
        
        #TODO: escape user_id, to prevent SQL injection attacks
        #Also double check that the weights are really working correctly
        
        inner_query = """
             SELECT  
                id,
              user1 AS u1,
              user2 AS u2,
              weight as w

            FROM user_matches
            WHERE user1="%s" OR user2="%s"
            GROUP BY id """ % (user_id,user_id)
        
        avg_query = """
        SELECT user_matches.* FROM (
            SELECT 
              x1.id AS idKey,
              x1.u1,
              x1.u2,
              x1.w,
              SUM(x2.w) AS RunningTotal
            FROM
            (
               """ + inner_query + """
            ) AS x1
            INNER JOIN (
              """ + inner_query + """
            ) AS x2
            ON x1.id >= x2.id
            GROUP BY x1.id
            order by RunningTotal
        ) as WeightedAvg, user_matches WHERE (WeightedAvg.RunningTotal > %i) AND WeightedAvg.idKey = user_matches.id
        
        ORDER BY WeightedAvg.RunningTotal LIMIT 0,1;""" % (weighted_idx)

        result = self.db.query(avg_query)

        if len(result) == 0: return []
        row = result[0]
        
        if row.user1 == user_id:
            return row.user2
        else:
            return row.user1
    
    def user_exists(self,user_id):
        retval = self.db.select("users",dict(id=user_id),where="id = $id")
        
        return len(retval) == 1

class UserDoesNotExistException(Exception):
    def __init__(self, user):
        self.user = user
    def __str__(self):
        return "User %s does not exist!" % self.user