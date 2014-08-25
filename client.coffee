Plugin = require 'plugin'
Obs = require 'obs'
Dom = require 'dom'
Form = require 'form'
Server = require 'server'
Time = require 'time'
Db = require 'db'
Page = require 'page'
Photo = require 'photo'
Widgets = require 'widgets'
{tr} = require 'i18n'

shared = Db.shared
personal = Db.personal


renderPhotoAndComments = (photoId) !->
	# bigger photoview, including comments
	Dom.style padding: 0
	photo = (shared photoId)

	userId = (photo 'userId')
	if Math.abs(0|(personal "#{photoId} seenTime")) < (photo 'lastEventTime')
		Server.sync 'seen', photoId
	
	Dom.div !->
		Dom.style
			position: 'relative'
			height: (Dom.viewport 'width') + 'px'
			width: (Dom.viewport 'width') + 'px'
			background: Photo.css (photo 'key'), 1080
			backgroundPosition: '50% 50%'
			backgroundSize: 'cover'
		if userId is Plugin.userId() or Plugin.userIsAdmin()
			Dom.onTap !->
				require('modal').show null, tr("Remove photo?"), (choice) !->
					if choice is 'remove'
						Server.sync 'remove', photoId, !->
							(shared photoId, null)
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
		(shared "#{photoId} comments")? (id, data) !->
			Dom.div !->
				Dom.style
					display_: 'box'
					_boxAlign: 'center'

				Dom.div !->
					Dom.style
						width: '40px'
						height: '40px'
						backgroundSize: 'cover'
						backgroundPosition: '50% 50%'
						#border: 'solid 2px #aaa'
						borderRadius: '20px'
					if avatar = Plugin.userAvatar(data 'userId')
						Dom.style
							backgroundImage: Photo.css(avatar)
							_boxShadow: '0 0 3px rgba(255,255,255,1)'
					else
						Dom.style
							backgroundImage:  "url(#{Plugin.resourceUri('silhouette-aaa.png')})"
							width: '36px'
							height: '36px'
							border: 'solid 2px #aaa'

				Dom.section !->
					Dom.style
						_boxFlex: 1
						marginLeft: '8px'
						margin: '4px'
					Dom.text (data 'comment')
					Dom.div !->
						Dom.style
							textAlign: 'left'
							fontSize: '70%'
							color: '#aaa'
							padding: '2px 0 0'
						Dom.text (Plugin.users "#{(data 'userId')} public name")
						Dom.text " - "
						Time.deltaText (data 'time')

		editingItem = Obs.value(false)
		Dom.div !->
			Dom.style display_: 'box', _boxAlign: 'center', margin: '12px 0'

			Dom.div !->
				Dom.style
					width: '40px'
					height: '40px'
					backgroundSize: 'cover'
					backgroundPosition: '50% 50%'
					borderRadius: '20px'
				if avatar = Plugin.userAvatar()
					Dom.style
						backgroundImage: Photo.css(avatar)
						_boxShadow: '0 0 3px rgba(255,255,255,1)'
				else
					Dom.style
						backgroundImage:  "url(#{Plugin.resourceUri('silhouette-aaa.png')})"
						width: '36px'
						height: '36px'
						border: 'solid 2px #aaa'

			addE = null
			save = !->
				return if !addE.value().trim()
				Server.sync 'addComment', photoId, addE.value().trim()
				addE.value ""
				(editingItem false)
				Form.blur()

			Dom.section !->
				Dom.style display_: 'box', _boxFlex: 1, _boxAlign: 'center', margin: '4px'
				Dom.div !->
					Dom.style _boxFlex: 1
					addE = Form.text
						autogrow: true
						name: 'comment'
						text: tr("Add a comment")
						simple: true
						onEdit: (v) !->
							(editingItem !!v.trim())
						onReturn: save
						inScope: !->
							Dom.prop 'rows', 1
							Dom.style
								border: 'none'
								width: '100%'
								fontSize: '100%'

				Widgets.button !->
					Dom.style
						marginRight: 0
						visibility: (if editingItem() then 'visible' else 'hidden')
					Dom.text tr("Add")
				, save

	Dom.div !->
		Dom.style marginTop: '14px'
		Form.sep()
		Form.check
			name: 'notify'
			value: !((0|(personal "#{photoId} seenTime")) < 0)
			text: tr("Notify about new comments")
			onEdit: (v) !->
				Server.sync 'seen', photoId, !v


exports.render = !->
	if (photoId=(Page.state 0)) and (shared photoId)
		renderPhotoAndComments(photoId)
		Page.scroll('down') if (Page.state 1)

	else
		# main page: overview of the photos
		Dom.style padding: '2px'
		boxSize = Obs.value()
		Obs.observe !->
			width = (Dom.viewport 'width')
			cnt = (0|(width / 150)) || 1
			(boxSize (0|(width-((cnt+1)*4))/cnt))

		photoUpload = Obs.value()
		Dom.div !->
			Dom.style
				display: 'inline-block'
				verticalAlign: 'top'
				margin: '2px'
				background:  "url(#{Plugin.resourceUri('addphoto.png')}) 50% 50% no-repeat"
				backgroundSize: '32px'
				border: 'dashed 2px #aaa'
				height: (boxSize()-4) + 'px'
				width: (boxSize()-4) + 'px'
			Dom.onTap !->
				Photo.pick()

		Dom.div !->
			if not photoUpload()
				Dom.style display: 'none'
				return

			Dom.style
				display: 'inline-block'
				margin: '2px'
				height: boxSize() + 'px'
				width: boxSize() + 'px'
			Dom.div !->
				Dom.style
					display_: 'box'
					height: '100%'
					_boxAlign: 'center'
					_boxPack: 'center'
				Widgets.spinner 24

		firstV = Obs.value(-Math.max(1, ((shared '#maxId')||0)-10))
		lastV = Obs.value()
		Obs.observe !->
			(lastV -(shared "maxId"))

		#(shared "maxId") # TODO: better fix for initial photo bug!

		(require 'loglist').render lastV, firstV, (num) !->
			num = -num
			p = (shared num) # 'p', to prevent variable clash :|

			return if typeof p!='function' # shouldn't happen

			Dom.div !->
				Dom.style
					display: 'inline-block'
					margin: '2px'
					width: boxSize() + 'px'
				Dom.div !->
					Dom.style
						display: 'inline-block'
						position: 'relative'
						height: boxSize() + 'px'
						width: boxSize() + 'px'
						background: "url(#{Photo.url (p 'key'), 500}) 50% 50% no-repeat"
						backgroundSize: 'cover'

					Dom.onTap !->
						Page.nav num

					seenTime = Math.abs(0|(personal "#{num} seenTime"))
					lastEventTime = 0|(p 'lastEventTime')
					if seenTime < lastEventTime
						newCount = Obs.value(0)
						Obs.observe !->
							c = 0
							for k, v of (p 'comments')?()
								c++ if (v 'time') > seenTime
							(newCount c)

						Dom.div !->
							Dom.style
								position: 'absolute'
								bottom: 0
								left: 0
								right: 0
								color: '#fff'
								lineHeight: '40px'
								textAlign: 'center'
								backgroundColor: 'rgba(0, 0, 0, 0.5)'
								padding: '4px'
								fontWeight: 'bold'
								fontSize: '85%'
								textTransform: 'uppercase'

							Dom.text (if +(p 'lastEventTime') is +(p 'time') then tr("New photo") else tr("%1 new comment|s", newCount()))
							Dom.onTap !->
								Page.nav [num, true] # scroll down

		Dom.div !->
			if firstV()==-1
				Dom.style display: 'none'
				return
			Dom.style
				padding: '4px'
				textAlign: 'center'

			Widgets.button tr("Earlier photos"), !->
				firstV Math.min(-1, Obs.peek(firstV)+10)
