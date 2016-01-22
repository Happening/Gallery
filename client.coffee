Comments = require 'comments'
Db = require 'db'
Dom = require 'dom'
Event = require 'event'
Form = require 'form'
Icon = require 'icon'
Modal = require 'modal'
Obs = require 'obs'
Page = require 'page'
Photo = require 'photo'
App = require 'app'
Server = require 'server'
Time = require 'time'
Ui = require 'ui'
Loglist = require 'loglist'
{tr} = require 'i18n'

shared = Db.shared
personal = Db.personal

renderPhotoAndComments = (photoId) !->
	# bigger photoview, including comments
	Dom.style padding: 0
	Event.showStar tr("this photo")

	contentFunc = (photoId) !->
		photo = shared.ref(photoId)
		byUserId = photo.get('userId')
		Dom.style margin: '0px'
		Dom.div !->
			Dom.style
				padding: '8px'
				backgroundColor: '#333',
				textAlign: 'center'
				height: '13px' # make sure the photoview's height correction is pixel-perfect (13+2*8 = 29)
			Dom.div !->
				Dom.style fontSize: '70%', color: '#aaa'
				Dom.text tr("Photo by %1", if byUserId is App.userId() then tr("you") else App.userName(byUserId))
				Dom.text " • "
				Time.deltaText photo.get('time'), 'short'
				Dom.text " • "
				Comments.renderLike
					store: ['likes', photoId+'-p'+photoId] # legacy path.. wtf!
					userId: byUserId
					noExpand: true
					color: 'white'
					aboutWhat: tr("photo")

		Comments.enable legacyStore: photoId
		Page.setTitle tr("Photo by %1", if byUserId is App.userId() then tr("you") else App.userName(byUserId))
		opts = []
		if Photo.share
			opts.push
				label: tr('Share')
				icon: 'share'
				action: !-> Photo.share photo.peek('key')
		if Photo.download
			opts.push
				label: tr('Download')
				icon: 'download'
				action: !-> Photo.download photo.peek('key')
		if byUserId is App.userId() or App.userIsAdmin()
			opts.push
				label: tr('Remove')
				icon: 'delete'
				action: !->
					Modal.confirm null, tr("Remove photo?"), !->
						Server.sync 'remove', photoId, !->
							shared.remove(photoId)
						Page.back()

		Page.setActions opts
		Page.state.set 0, photoId

	(require 'photoview').render
		current: photoId
		getNeighbourIds: (id) ->
			max = Db.shared.peek('maxId')||0
			right = parseInt(id)-1
			while !Db.shared.isHash(right) && right > 0
				right--
			left = parseInt(id)+1
			while !Db.shared.isHash(left) && left <= max
				left++
			left = undefined if !Db.shared.isHash(left)
			right = undefined if !Db.shared.isHash(right)
			[left,right]
		idToPhotoKey: (id) ->
			Db.shared.peek(id, 'key')
		height: -> Page.height() - 29 # space for subtext
		fullHeight: true
		content: contentFunc

exports.renderSettings = !->
	Form.input
		name: '_title'
		text: tr('Optional gallery topic')
		value: App.title()

exports.render = !->
	photoId = Page.state.peek(0)
	if photoId is '_settings'
		log "we should not be rendering the client!"
		photoId = null
	if photoId # and shared.get(photoId)
		# we shouldn't redraw this scope whenever something with the photo changes
		renderPhotoAndComments(photoId)
		Page.scroll('down') if Page.state.peek(1)
		return

	# main page: overview of the photos
	Dom.style padding: '2px'
	boxSize = Obs.create()
	Obs.observe !->
		width = Page.width()
		cnt = (0|(width / 100)) || 1
		boxSize.set(0|(width-((cnt+1)*4))/cnt)

	Dom.div !->
		Dom.cls 'add'
		Dom.style
			display: 'inline-block'
			position: 'relative'
			verticalAlign: 'top'
			margin: '2px'
			background:  "url(#{App.resourceUri('addphoto.png')}) 50% 50% no-repeat"
			backgroundSize: '32px'
			border: 'dashed 2px #aaa'
			height: (boxSize.get()-4) + 'px'
			width: (boxSize.get()-4) + 'px'
		Dom.onTap !->
			# TODO: subscribe serverside
			Event.subscribe [(shared.get('maxId')||0)+1]
			Photo.pick()

	Photo.uploads.observeEach (upload) !->
		Dom.div !->
			Dom.style
				margin: '2px'
				display: 'inline-block'
				verticalAlign: 'top'
				Box: 'inline right bottom'
				height: boxSize.get() + 'px'
				width: boxSize.get() + 'px'
			if thumb = upload.get('thumb')
				Dom.style
					background: "url(#{thumb}) 50% 50% no-repeat"
					backgroundSize: 'cover'
			Dom.cls 'photo'
			Ui.spinner
				size: 24
				content: !->
					Dom.style margin: '4px'
				light: true

	if fv = Page.state.get('firstV')
		firstV = Obs.create(fv)
	else
		firstV = Obs.create(-Math.max(1, (shared.peek('maxId')||0)-50))
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

				Event.renderBubble
					path: [photo.key()]
					style:
						position: 'absolute'
						top: '15px'
						right: 0

	Dom.div !->
		if firstV.get()==-1
			Dom.style display: 'none'
			return
		Dom.style
			padding: '4px'
			textAlign: 'center'

		Ui.button tr("Earlier photos"), !->
			fv = Math.min(-1, firstV.peek()+50)
			firstV.set fv
			Page.state.set('firstV', fv)

	Obs.observe !->
		if empty.get() and !Photo.uploads.count().get()
			Dom.div !->
				Dom.style
					display: 'inline-block'
					height: boxSize.get()-20 + 'px'
					width: 1.4*boxSize.get() + 'px'
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

