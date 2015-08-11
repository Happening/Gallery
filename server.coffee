Plugin = require 'plugin'
Db = require 'db'
Event = require 'event'
Photo = require 'photo'

###
exports.onUpgrade  = !->
	log 'trying onUpgrade'

	# check whether data has been upgrade to comments api, otherwise convert to photoId -> commentId -> c/t/u format
	if !Db.shared.get('comments')
		log 'upgrading comments'

		allComments = {}
		Db.shared.forEach (data) !->
			return if !+data.key()
			oldComments = data.get('comments')
			return if !oldComments

			allComments[data.key()] = {}
			newMax = 0
			for commentId, comment of oldComments
				newComment =
					c: comment.comment
					t: +comment.time
					u: +comment.userId
				allComments[data.key()][commentId] = newComment
				newMax = commentId if (commentId > newMax)

			allComments[data.key()]['max'] = +newMax
			Db.shared.remove(data.key(), 'comments')
			Db.shared.remove(data.key(), 'maxCommentId')

		#log 'new comments: '+JSON.stringify(allComments)
		#Db.shared.merge('comments', allComments)
###


exports.onPhoto = (info) !->
	maxId = Db.shared.modify 'maxId', (v) -> (v||0) + 1

	nowTime = Math.round(Date.now()/1000)
	info.time = nowTime
	Db.shared.set(maxId, info)

	name = Plugin.userName()
	Event.create
		unit: 'photo'
		text: "#{name} added a photo"
		sender: Plugin.userId()
		#nav: [maxId]
		# doesn't work yet

exports.client_remove = (photoId) !->
	userId = Db.shared.get(photoId, 'userId')
	return if userId != Plugin.userId() and !Plugin.userIsAdmin()

	Photo.remove key if key = Db.shared.get(photoId, 'key')
	Db.shared.remove(photoId)

