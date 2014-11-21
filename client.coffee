Db = require 'db'
Dom = require 'dom'
Form = require 'form'
Obs = require 'obs'
Page = require 'page'
Photo = require 'photo'
Plugin = require 'plugin'
Server = require 'server'
Social = require 'social'
Time = require 'time'
Ui = require 'ui'
Loglist = require 'loglist'
{tr} = require 'i18n'

shared = Db.shared
personal = Db.personal

renderPhotoAndComments = (photoId) !->
	# bigger photoview, including comments
	Dom.style padding: 0
	photo = shared.ref(photoId)

	byUserId = photo.get('userId')

	Page.setTitle tr("Photo")
	
	# remove button
	if byUserId is Plugin.userId() or Plugin.userIsAdmin()
		Page.setActions
			icon: Plugin.resourceUri('icon-trash-48.png')
			action: !->
				require('modal').confirm null, tr("Remove photo?"), !->
					Server.sync 'remove', photoId, !->
						shared.remove(photoId)
					Page.back()

	Dom.div !->
		Dom.style
			position: 'relative'
			height: Dom.viewport.get('width') + 'px'
			width: Dom.viewport.get('width') + 'px'
			background: Photo.css photo.get('key'), 800
			backgroundPosition: '50% 50%'
			backgroundSize: 'cover'

		Dom.div !->
			Dom.style
				position: 'absolute'
				bottom: '5px'
				left: '10px'
				fontSize: '70%'
				textShadow: '0 1px 0 #000'
				color: '#fff'
			if byUserId is Plugin.userId()
				Dom.text tr("Added by you")
			else
				Dom.text tr("Added by %1", Plugin.userName(byUserId))
			Dom.text " • "
			Time.deltaText photo.get('time')

	Social.renderComments(photoId)


exports.render = !->
	photoId = Page.state.get(0)
	if photoId # and shared.get(photoId)
		# we shouldn't redraw this scope whenever something with the photo changes
		renderPhotoAndComments(photoId)
		Page.scroll('down') if Page.state.get(1)
		return

	# main page: overview of the photos
	Dom.style padding: '2px'
	boxSize = Obs.create()
	Obs.observe !->
		width = Dom.viewport.get('width')
		cnt = (0|(width / 100)) || 1
		boxSize.set(0|(width-((cnt+1)*4))/cnt)

	photoUpload = Obs.create()
	Photo.onBusy !->
		# temporary, private API
		photoUpload.set(true)

	if title = Plugin.title()
		Dom.h2 !->
			Dom.style margin: '6px 2px'
			Dom.text title

	Dom.div !->
		Dom.cls 'add'
		Dom.style
			display: 'inline-block'
			position: 'relative'
			verticalAlign: 'top'
			margin: '2px'
			background:  "url(#{Plugin.resourceUri('addphoto.png')}) 50% 50% no-repeat"
			backgroundSize: '32px'
			border: 'dashed 2px #aaa'
			height: (boxSize.get()-4) + 'px'
			width: (boxSize.get()-4) + 'px'
		Dom.onTap !->
			Photo.pick()

	Dom.div !->
		if not photoUpload.get()
			Dom.style display: 'none'
			return

		Dom.style
			display: 'inline-block'
			margin: '2px'
			height: boxSize.get() + 'px'
			width: boxSize.get() + 'px'
		Dom.div !->
			Dom.style
				display_: 'box'
				height: '100%'
				_boxAlign: 'center'
				_boxPack: 'center'
			Ui.spinner 24

	if fv = Page.state.get('_firstV')
		firstV = Obs.create(fv)
	else
		firstV = Obs.create(-Math.max(1, (shared.peek('maxId')||0)-10))
	lastV = Obs.create()
		# firstV and lastV are inversed when they go into Loglist
	Obs.observe !->
		lastV.set -(shared.get('maxId')||0)

	Loglist.render lastV, firstV, (num) !->
		num = -num
		photo = shared.ref(num)
		return if !photo.get('key')

		photoUpload.set(false)

		Dom.div !->
			Dom.style
				display: 'inline-block'
				margin: '2px'
				width: boxSize.get() + 'px'
			Dom.div !->
				Dom.style
					display: 'inline-block'
					position: 'relative'
					height: boxSize.get() + 'px'
					width: boxSize.get() + 'px'
					background: "url(#{Photo.url photo.get('key'), 200}) 50% 50% no-repeat"
					backgroundSize: 'cover'
				Dom.cls 'photo'

				Dom.onTap !->
					Page.nav num

				if unread = Social.newComments photo.key()
					Ui.unread unread, null, {position: 'absolute', top: '15px', right: 0}

	Dom.div !->
		if firstV.get()==-1
			Dom.style display: 'none'
			return
		Dom.style
			padding: '4px'
			textAlign: 'center'

		Ui.button tr("Earlier photos"), !->
			fv = Math.min(-1, firstV.peek()+10)
			firstV.set fv
			Page.state.set('_firstV', fv)

Dom.css
	'.add.tap::after, .photo.tap::after':
		content: '""'
		display: 'block'
		position: 'absolute'
		left: 0
		right: 0
		top: 0
		bottom: 0
		backgroundColor: 'rgba(0, 0, 0, 0.2)'

