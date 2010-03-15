import web
from models import *

# from ChatUser import ChatUser

urls = (
  '/', 'index',
)

render = web.template.render('templates', base='base')

class index:
    def GET(self):
        # user = users.get_current_user()

        return render.index()

    def POST(self):
        i = web.input()
        # person = Person()
        # person.name = i.name
        # person.put()
        return web.seeother('/list')
# 
# class listen:
#     def GET(self):
#         # return "Error."
#         return render.listen()
#     def POST(self):
#         return render.listen()
# 
# class call:
#     def GET(self):
#         return render.call()
# 
# class list:
#     def GET(self):
#         # people = db.GqlQuery("SELECT * FROM Person ORDER BY created DESC LIMIT 10")
#         return render.list(people)

app = web.application(urls, globals())
# main = app.cgirun()

if __name__ == "__main__": app.run()
