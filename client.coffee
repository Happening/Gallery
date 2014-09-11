Db = require 'db'
Dom = require 'dom'
Form = require 'form'
Obs = require 'obs'
Page = require 'page'
Photo = require 'photo'
Plugin = require 'plugin'
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
	photo = shared.ref(photoId)

	userId = photo.get('userId')
	Obs.observe !->
		if Math.abs(0|(personal.get(photoId, 'seenTime'))) < photo.get('lastEventTime')
			Server.sync 'seen', photoId
	
	Dom.div !->
		Dom.style
			position: 'relative'
			height: Dom.viewport.get('width') + 'px'
			width: Dom.viewport.get('width') + 'px'
			background: Photo.css photo.get('key'), 800
			backgroundPosition: '50% 50%'
			backgroundSize: 'cover'
		if userId is Plugin.userId() or Plugin.userIsAdmin()
			Dom.onTap !->
				require('modal').show null, tr("Remove photo?"), (choice) !->
					if choice is 'remove'
						Server.sync 'remove', photoId, !->
							shared.remove(photoId)
						Page.back()
				, ['cancel', tr("Cancel"), 'remove', tr("Remove")]

		Dom.div !->
			Dom.style
				position: 'absolute'
				left: 0
				right: 0
				bottom: '10px'
				color: 'white'
				textShadow: '0 1px 0 #000'
				textAlign: 'center'
			if userId is Plugin.userId()
				Dom.text tr("Your photo: tap to remove.")
			else if Plugin.userIsAdmin()
				Dom.text tr("Shared by %1: tap to remove", Plugin.userName(userId))
			else
				Dom.text tr("Shared by %1", Plugin.userName(userId))

	Dom.div !->
		Dom.style margin: '8px'
		shared.ref(photoId, 'comments')?.iterate (comment) !->
			Dom.div !->
				Dom.style
					display_: 'box'
					_boxAlign: 'center'

				Ui.avatar Plugin.userAvatar(comment.get('userId'))

				Dom.section !->
					Dom.style
						_boxFlex: 1
						marginLeft: '8px'
						margin: '4px'
					Dom.text comment.get('comment')
					Dom.div !->
						Dom.style
							textAlign: 'left'
							fontSize: '70%'
							color: '#aaa'
							padding: '2px 0 0'
						Dom.text Plugin.userName(comment.get('userId'))
						Dom.text " • "
						Time.deltaText comment.get('time')

	editingItem = Obs.create(false)
	Dom.div !->
		Dom.style display_: 'box', _boxAlign: 'center', margin: '8px'

		Ui.avatar Plugin.userAvatar()

		addE = null
		save = !->
			return if !addE.value().trim()
			Server.sync 'addComment', photoId, addE.value().trim()
			addE.value ""
			editingItem.set(false)
			Form.blur()

		Dom.section !->
			Dom.style display_: 'box', _boxFlex: 1, _boxAlign: 'center', margin: '4px'
			Dom.div !->
				Dom.style _boxFlex: 1
				log 'rendering form.text'
				addE = Form.text
					autogrow: true
					name: 'comment'
					text: tr("Add a comment")
					simple: true
					onChange: (v) !->
						editingItem.set(!!v?.trim())
					onReturn: save
					inScope: !->
						Dom.prop 'rows', 1
						Dom.style
							border: 'none'
							width: '100%'
							fontSize: '100%'

			Ui.button !->
				Dom.style
					marginRight: 0
					visibility: (if editingItem.get() then 'visible' else 'hidden')
				Dom.text tr("Add")
			, save

	Dom.div !->
		Dom.style marginTop: '14px'
		Form.sep()
		Form.check
			name: 'notify'
			value: !((0|(personal.get(photoId, 'seenTime'))) < 0)
			text: tr("Notify about new comments")
			onSave: (v) !->
				Server.sync 'seen', photoId, !v


exports.render = !->
	photoId = Page.state.get(0)
	if photoId and shared.get(photoId)
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

	Dom.div !->
		Dom.style
			display: 'inline-block'
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

				seenTime = Math.abs(0|(personal.get(num, 'seenTime')))
				lastEventTime = 0|photo.get('lastEventTime')
				if seenTime < lastEventTime
					Dom.div !->
						Dom.style
							position: 'absolute'
							bottom: 0
							left: 0
							right: 0
							color: '#fff'
							lineHeight: '30px'
							textAlign: 'center'
							backgroundColor: 'rgba(0, 0, 0, 0.5)'
							padding: '4px'
							fontWeight: 'bold'
							fontSize: '75%'
							textTransform: 'uppercase'

						if +photo.get('lastEventTime') is +photo.get('time')
							Dom.text tr("New photo")
						else
							newCount = photo.ref('comments').map( (c) -> if c.get('time') > seenTime then c ).count()
							Dom.text tr("+%1 comment|s", newCount.get())
						Dom.onTap !->
							Page.nav [num, 'end'] # scroll down

	Dom.div !->
		if firstV.get()==-1
			Dom.style display: 'none'
			return
		Dom.style
			padding: '4px'
			textAlign: 'center'

		Ui.button tr("Earlier photos"), !->
			firstV.set Math.min(-1, firstV.peek()+10)

Dom.css
	'.photo.tap::after':
		content: '""'
		display: 'block'
		position: 'absolute'
		left: 0
		right: 0
		top: 0
		bottom: 0
		backgroundColor: 'rgba(0, 0, 0, 0.3)'

