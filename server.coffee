Plugin = require 'plugin'
Db = require 'db'
Event = require 'event'
#Photo = require 'photo'

exports.onPhoto = (info) !->
	maxId = Db.shared.modify 'maxId', (v) -> (v||0) + 1

	nowTime = Math.round(Date.now()/1000)
	info.time = nowTime
	info.lastEventTime = nowTime
	Db.shared.set(maxId, info)

	personal = Db.personal Plugin.userId()
	personal.set maxId, 'seenTime', nowTime

	name = Plugin.userName()
	Event.create
		unit: 'photo'
		text: "#{name} added a photo"
		read: [Plugin.userId()]

exports.client_seen = (photoId, mute) !->
	personal = Db.personal Plugin.userId()
	mute = personal.get(photoId, 'seenTime')<0 if typeof mute is 'undefined'

	personal.set photoId, 'seenTime', (if mute then -1 else 1) * Math.round(Date.now()*.001)
		# negative time means the photo has been muted

exports.client_addComment = (photoId, comment) !->
	maxCommentId = Db.shared.modify photoId, 'maxCommentId', (v) -> (v||0) + 1
	nowTime = Math.round(Date.now()*.001)

	Db.shared.set photoId, 'lastEventTime', nowTime
	Db.shared.set photoId, 'comments', maxCommentId,
		userId: Plugin.userId()
		time: nowTime
		comment: comment

	Event.create
		unit: 'comment'
		exclude: (userId for userId in Plugin.userIds() when Db.personal(userId).get(photoId, 'seenTime') < 0)
			# have the photo muted 
		text: "Comment by #{Plugin.userName()}: #{comment}"
		read: [Plugin.userId()]

exports.client_remove = (photoId) !->
	log "removing photo #{photoId}"
	
	userId = Db.shared.get(photoId, 'userId')
	return if userId != Plugin.userId() and !Plugin.userIsAdmin()

	Db.shared.remove(photoId)

	# todo: Photo.remove

