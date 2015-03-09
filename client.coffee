Db = require 'db'
Dom = require 'dom'
Event = require 'event'
Form = require 'form'
Icon = require 'icon'
Modal = require 'modal'
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
	Event.showStar tr("this photo")

	opts = []
	if Photo.share
		opts.push
			label: tr('Share')
			icon: 'share'
			action: !-> Photo.share photo.peek('key')
	if Photo.download
		opts.push
			label: tr('Download')
			icon: 'boxdown'
			action: !-> Photo.download photo.peek('key')
	if byUserId is Plugin.userId() or Plugin.userIsAdmin()
		opts.push
			label: tr('Remove')
			icon: 'trash'
			action: !->
				Modal.confirm null, tr("Remove photo?"), !->
					Server.sync 'remove', photoId, !->
						shared.remove(photoId)
					Page.back()
	
	Page.setActions opts

	(require 'photoview').render
		key: photo.get('key')
		content: !->
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

	Photo.uploads.observeEach (upload) !->
		Dom.div !->
			Dom.style
				margin: '2px'
				display: 'inline-block'
				Box: 'inline right bottom'
				height: boxSize.get() + 'px'
				width: boxSize.get() + 'px'
			if thumb = upload.get('thumb')
				Dom.style
					background: "url(#{thumb}) 50% 50% no-repeat"
					backgroundSize: 'cover'
			Dom.cls 'photo'
			Ui.spinner 24, undefined, 'spin-light.png'

	if fv = Page.state.get('firstV')
		firstV = Obs.create(fv)
	else
		firstV = Obs.create(-Math.max(1, (shared.peek('maxId')||0)-10))
	lastV = Obs.create()
		# firstV and lastV are inversed when they go into Loglist
	Obs.observe !->
		lastV.set -(shared.get('maxId')||0)

	log 'firstV, lastV', firstV.get(), lastV.get()
	photoCnt = 0
	empty = Obs.create(true)
	Loglist.render lastV, firstV, (num) !->
		num = -num
		photo = shared.ref(num)
		return if !photo.get('key')

		empty.set(!++photoCnt)
		Obs.onClean !->
			empty.set(!--photoCnt)

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

				Event.renderBubble [photo.key()], style: { position: 'absolute', top: '15px', right: 0 }

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
			Page.state.set('firstV', fv)

	Obs.observe !->
		if empty.get() and !Photo.uploads.count().get()
			Dom.div !->
				Dom.style
					display: 'inline-block'
					height: boxSize.get()-20 + 'px'
					width: 2*boxSize.get()-20 + 'px'
					padding: '10px'

				Dom.div !->
					Dom.style
						Box: 'center middle'
						height: '100%'
						textAlign: 'center'
						color: '#aaa'
					Dom.text tr("No photos or images have been added yet")

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

