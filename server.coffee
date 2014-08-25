Plugin = require 'plugin'
Db = require 'db'
Event = require 'event'
#Photo = require 'photo'

exports.onPhoto = (info) !->
	maxId = 1 + (0|(Db.shared 'maxId'))
	(Db.shared 'maxId', maxId)

	nowTime = Math.round(Date.now()/1000)
	info.time = nowTime
	info.lastEventTime = nowTime
	(Db.shared maxId, info)

	personal = Db.personal Plugin.userId()
	(personal "#{maxId} seenTime", nowTime)

	name = Plugin.userName()
	Event.create
		unit: 'msg'
		text: "#{name} added a photo"
		read: [Plugin.userId()]

exports.client_seen = (photoId, mute) !->
	personal = Db.personal Plugin.userId()
	mute = (personal "#{photoId} seenTime")<0 if typeof mute is 'undefined'

	(personal "#{photoId} seenTime", (if mute then -1 else 1) * Math.round(Date.now()/1000))
		# negative time means the photo has been muted

exports.client_addComment = (photoId, comment) !->
	maxCommentId = 1 + (0|(Db.shared "#{photoId} maxCommentId"))
	nowTime = Math.round(Date.now()/1000)
	commentObj =
		userId: Plugin.userId()
		time: nowTime
		comment: comment

	(Db.shared "#{photoId} lastEventTime", nowTime)
	(Db.shared "#{photoId} comments #{maxCommentId}", commentObj)
	(Db.shared "#{photoId} maxCommentId", maxCommentId)

	# find out who has this photo muted
	excludeUids = (userId for userId in Plugin.userIds() when (Db.personal(userId) "#{photoId} seenTime")<0)

	name = Plugin.userName()
	Event.create
		unit: 'comment'
		exclude: excludeUids
		text: "Comment by #{name}: #{comment}"
		read: [Plugin.userId()]

exports.client_remove = (photoId) !->
	log "removing photo #{photoId}"
	#if key = (Db.shared "#{photoId} key")
	#	Photo.remove key
	
	userId = (Db.shared "#{photoId} userId")
	return if userId != Plugin.userId() and !Plugin.userIsAdmin()

	(Db.shared photoId, null)

