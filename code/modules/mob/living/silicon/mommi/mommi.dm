/*  Basically, the concept is this:
You have an MMI.  It can't do squat on its own.
Now you put some robot legs and arms on the thing, and POOF!  You have a Mobile MMI, or MoMMI.
Why?  MoMMIs can do all sorts of shit, like ventcrawl, do shit with their hands, etc.
They can only use one tool at a time, they can't choose modules, and they have 1/6th the HP of a borg.
*/
/mob/living/silicon/robot/mommi
	name = "Mobile MMI"
	real_name = "Mobile MMI"
	icon = 'icons/mob/robots.dmi'
	icon_state = "mommi"
	maxHealth = 60
	health = 60
	pass_flags = PASSTABLE
	var/keeper=0 // 0 = No, 1 = Yes (Disables speech and common radio.)
	var/picked = 0
	var/subtype="keeper"
	var/obj/screen/inv_tool = null

	static_overlays
	var/static_choice = "static"
	var/list/static_choices = list("static", "letter", "blank")

	mob_bump_flag = ROBOT
	mob_swap_flags = ALLMOBS
	mob_push_flags = 0
	//var/obj/screen/inv_sight = null

//one tool and one sightmod can be activated at any one time.
	var/tool_state = null
	var/sight_state = null
	var/head_state = null

	modtype = "robot" // Not sure what this is, but might be cool to have seperate loadouts for MoMMIs (e.g. paintjobs and tools)
	//Cyborgs will sync their laws with their AI by default, but we may want MoMMIs to be mute independents at some point, kinda like the Keepers in Ass Effect.
	lawupdate = 1

	speed = 0

/mob/living/carbon/can_use_hands()
	return 1

/mob/living/silicon/robot/mommi/generate_static_overlay()
	if(!istype(static_overlays,/list))
		static_overlays = list()
	return

/mob/living/silicon/robot/mommi/examination(atom/A as mob|obj|turf in view()) //It used to be oview(12), but I can't really say why
	if(ismob(A) && src.can_see_static()) //can't examine what you can't catch!
		usr << "Your vision module can't determine any of [A]'s features."
		return

	..()


/mob/living/silicon/robot/mommi/New(loc)
	spark_system = new /datum/effect/effect/system/spark_spread()
	spark_system.set_up(5, 0, src)
	spark_system.attach(src)

	ident = rand(1, 999)
	updatename()
	updateicon()

	if(!cell)
		cell = new /obj/item/weapon/cell(src)
		cell.maxcharge = 7500
		cell.charge = 7500
	..(loc,startup_sound='sound/misc/interference.ogg')
	module = new /obj/item/weapon/robot_module/mommi(src)
	laws = new mommi_base_law_type

	// Don't sync if we're a KEEPER.
	if(!istype(laws,/datum/ai_laws/keeper))
		connected_ai = select_active_ai_with_fewest_borgs()
	else
		// Enforce silence.
		keeper=1
		connected_ai = null // Enforce no AI parent
		scrambledcodes = 1 // Hide from console because people are fucking idiots

	if(connected_ai)
		connected_ai.connected_robots += src
		lawsync()
		lawupdate = 1
	else
		lawupdate = 0

	if(!scrambledcodes && !camera)
		camera = new /obj/machinery/camera(src)
		camera.c_tag = real_name
		camera.network = list("SS13")
		if(wires.IsCameraCut()) // 5 = BORG CAMERA
			camera.status = 0

	// Sanity check
	if(connected_ai && keeper)
		world << "<span class='warning'>ASSERT FAILURE: connected_ai && keeper in mommi.dm</span>"


/mob/living/silicon/robot/mommi/choose_icon()
	var/icontype = input("Select an icon!", "Mobile MMI", null) in list("Basic", "Hover", "Keeper", "RepairBot", "Replicator", "Prime", "Scout")
	switch(icontype)
		if("Replicator") subtype = "replicator"
		if("Keeper")	 subtype = "keeper"
		if("RepairBot")	 subtype = "repairbot"
		if("Hover")	     subtype = "hovermommi"
		if("Prime")	     subtype = "mommiprime"
		if("Scout")	     subtype = "scout"
		else			 subtype = "mommi"
	updateicon()
	var/answer = input("Is this what you want?", "Mobile MMI", null) in list("Yes", "No")
	switch(answer)
		if("No")
			choose_icon()
			return
	picked = 1

/mob/living/silicon/robot/mommi/pick_module()

	if(module)
		return
	var/list/modules = list("MoMMI")
	if(modules.len)
		modtype = input("Please, select a module!", "Robot", null, null) in modules
	else
		modtype=modules[0]

	var/module_sprites[0] //Used to store the associations between sprite names and sprite index.

	if(module)
		return

	switch(modtype)
		if("MoMMI")
			module = new /obj/item/weapon/robot_module/standard(src)
			module_sprites["Basic"] = "mommi"
			module_sprites["Keeper"] = "keeper"
			module_sprites["Replicator"] = "replicator"
			module_sprites["RepairBot"] = "repairbot"
			module_sprites["Hover"] = "hovermommi"
			module_sprites["Prime"] = "mommiprime"

	//Custom_sprite check and entry
	if (custom_sprite == 1)
		module_sprites["Custom"] = "[src.ckey]-[modtype]"

	hands.icon_state = lowertext(modtype)
	feedback_inc("mommi_[lowertext(modtype)]",1)
	updatename()

	choose_icon(6,module_sprites)
	base_icon = icon_state

//If there's an MMI in the robot, have it ejected when the mob goes away. --NEO
//Improved /N
/mob/living/silicon/robot/mommi/Destroy()
	remove_static_overlays()
	if(mmi)//Safety for when a cyborg gets dust()ed. Or there is no MMI inside.
		var/obj/item/device/mmi/nmmi = mmi
		var/turf/T = get_turf(loc)//To hopefully prevent run time errors.
		if(T)	nmmi.loc = T
		if(mind)	mind.transfer_to(nmmi.brainmob)
		mmi = null
		nmmi.icon = 'icons/obj/assemblies.dmi'
		nmmi.invisibility = 0
	..()

/mob/living/silicon/robot/mommi/remove_screen_objs()
	..()
	if(inv_tool)
		returnToPool(inv_tool)
		inv_tool = null

/mob/living/silicon/robot/mommi/updatename(var/prefix as text)

	var/changed_name = ""
	if(custom_name)
		changed_name = custom_name
	else
		changed_name = "Mobile MMI [num2text(ident)]"
	real_name = changed_name
	name = real_name

/mob/living/silicon/robot/mommi/emag_act(mob/user as mob)
	if(user == src && emagged != 1)//Dont shitpost inside the game, thats just going too far
		user << "<span class='warning'>Nanotrasen Patented Anti-Emancipation Override initiated.</span>"
		return
	..()
	remove_static_overlays()
	updateicon()

/mob/living/silicon/robot/mommi/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/weldingtool))
		var/obj/item/weapon/weldingtool/WT = W
		if (WT.remove_fuel(0))
			adjustBruteLoss(-30)
			updatehealth()
			add_fingerprint(user)
			for(var/mob/O in viewers(user, null))
				O.show_message(text("<span class='warning'>[user] has fixed some of the dents on [src]!</span>"), 1)
		else
			user << "Need more welding fuel!"
			return

	else if(istype(W, /obj/item/stack/cable_coil) && wiresexposed)
		var/obj/item/stack/cable_coil/coil = W
		adjustFireLoss(-30)
		updatehealth()
		coil.use(1)
		for(var/mob/O in viewers(user, null))
			O.show_message(text("<span class='warning'>[user] has fixed some of the burnt wires on [src]!</span>"), 1)

	else if (istype(W, /obj/item/weapon/crowbar))	// crowbar means open or close the cover
		if(stat == DEAD)
			user << "You pop the MMI off the base."
			spawn(0)
				del(src)
			return
		if(opened)
			if(mmi && wiresexposed && wires.IsAllCut())
				//Cell is out, wires are exposed, remove MMI, produce damaged chassis, baleet original mob.
				user << "You jam the crowbar into \the [src] and begin levering [mmi]."
				if (do_after(user, src,3))
					user << "You damage some parts of the casing, but eventually manage to rip out [mmi]!"
					var/limbs = list(/obj/item/robot_parts/l_leg, /obj/item/robot_parts/r_leg, /obj/item/robot_parts/l_arm, /obj/item/robot_parts/r_arm)
					for(var/newlimb = 1 to rand(2, 4))
						var/limb_to_spawn = pick(limbs)
						limbs -= limb_to_spawn

						new limb_to_spawn(src.loc)
					// This doesn't work.  Don't use it.
					//src.Destroy()
					// del() because it's infrequent and mobs act weird in qdel.
					del(src)
					return
			else
				user << "You close the cover."
				opened = 0
				updateicon()
		else
			if(locked)
				user << "The cover is locked and cannot be opened."
			else
				user << "You open the cover."
				opened = 1
				updateicon()

	else if (istype(W, /obj/item/weapon/cell) && opened)	// trying to put a cell inside
		if(wiresexposed)
			user << "Close the panel first."
		else if(cell)
			user << "There is a power cell already installed."
		else
			user.drop_item(W, src)
			cell = W
			user << "You insert the power cell."
//			chargecount = 0
		updateicon()

	else if (istype(W, /obj/item/weapon/wirecutters) || istype(W, /obj/item/device/multitool))
		if (wiresexposed)
			wires.Interact(user)
		else
			user << "You can't reach the wiring."

	else if(istype(W, /obj/item/weapon/screwdriver) && opened && !cell)	// haxing
		wiresexposed = !wiresexposed
		user << "The wires have been [wiresexposed ? "exposed" : "unexposed"]"
		updateicon()

	else if(istype(W, /obj/item/weapon/screwdriver) && opened && cell)	// radio
		if(radio)
			radio.attackby(W,user)//Push it to the radio to let it handle everything
		else
			user << "Unable to locate a radio."
		updateicon()

	else if(istype(W, /obj/item/device/encryptionkey/) && opened)
		if(radio)//sanityyyyyy
			radio.attackby(W,user)//GTFO, you have your own procs
		else
			user << "Unable to locate a radio."
/*
	else if (istype(W, /obj/item/weapon/card/id)||istype(W, /obj/item/device/pda))			// trying to unlock the interface with an ID card
		if(emagged)//still allow them to open the cover
			user << "The interface seems slightly damaged"
		if(opened)
			user << "You must close the cover to swipe an ID card."
		else
			if(allowed(usr))
				locked = !locked
				user << "You [ locked ? "lock" : "unlock"] [src]'s interface."
				updateicon()
			else
				user << "<span class='warning'>Access denied.</span>"
*/

	else if(istype(W, /obj/item/borg/upgrade/))
		var/obj/item/borg/upgrade/U = W
		if(!opened)
			user << "You must access the borgs internals!"
		else if(!src.module && U.require_module)
			user << "The borg must choose a module before he can be upgraded!"
		else if(U.locked)
			user << "The upgrade is locked and cannot be used yet!"
		else
			if(istype(U, /obj/item/borg/upgrade/reset))
				user << "<span class='warning'>No.</span>"
				return
			if(U.action(src))
				user << "You apply the upgrade to [src]!"
				user.drop_item(U, src)
			else
				user << "Upgrade error!"

	else if(istype(W, /obj/item/device/camera_bug))
		help_shake_act(user)
		return 0

	else
		spark_system.start()
		return ..()

/mob/living/silicon/robot/mommi/attack_hand(mob/user)
	add_fingerprint(user)

	if(opened && !wiresexposed && (!istype(user, /mob/living/silicon)))
		if(cell)
			cell.updateicon()
			cell.add_fingerprint(user)
			user.put_in_active_hand(cell)
			user << "You remove \the [cell]."
			cell = null
			updateicon()
			return

	if(!istype(user, /mob/living/silicon))
		switch(user.a_intent)
			if(I_DISARM)
				user.attack_log += text("\[[time_stamp()]\] <font color='red'>Disarmed [src.name] ([src.ckey])</font>")
				src.attack_log += text("\[[time_stamp()]\] <font color='orange'>Has been disarmed by [user.name] ([user.ckey])</font>")
				log_admin("ATTACK: [user.name] ([user.ckey]) disarmed [src.name] ([src.ckey])")
				log_attack("<font color='red'>[user.name] ([user.ckey]) disarmed [src.name] ([src.ckey])</font>")
				var/randn = rand(1,100)
				//var/talked = 0;
				if (randn <= 25)
					weakened = 3
					playsound(loc, 'sound/weapons/thudswoosh.ogg', 50, 1, -1)
					visible_message("<span class='danger'>[user] has pushed [src]!</span>")
					var/obj/item/found = locate(tool_state) in src.module.modules
					if(!found)
						var/obj/item/TS = tool_state
						drop_item(TS)
						if(TS && TS.loc)
							visible_message("<span class='warning'><B>[src]'s robotic arm loses grip on what it was holding</span>")
					return
				if(randn <= 50)//MoMMI's robot arm is stronger than a human's, but not by much
					var/obj/item/found = locate(tool_state) in src.module.modules
					if(!found)
						var/obj/item/TS = tool_state
						drop_item(TS)
						playsound(loc, 'sound/weapons/thudswoosh.ogg', 50, 1, -1)
						visible_message("<span class='danger'>[user] has disarmed [src]!</span>")
					else
						playsound(loc, 'sound/weapons/punchmiss.ogg', 25, 1, -1)
						visible_message("<span class='danger'>[user] attempted to disarm [src]!</span>")
					return
			if (I_HELP)
				help_shake_act(user)
				return

/mob/living/silicon/robot/mommi/installed_modules()
	if(weapon_lock)
		src << "<span class='warning'>Weapon lock active, unable to use modules! Count:[weaponlock_time]</span>"
		return

	if(!module)
		pick_module()
		return
	if(!picked)
		choose_icon()
		return
	var/dat = "<HEAD><TITLE>Modules</TITLE><META HTTP-EQUIV='Refresh' CONTENT='10'></HEAD><BODY>\n"
	dat += {"<BR>
	<BR>
	<B>Activated Modules</B>
	<BR>
	Sight Mode: [sight_state ? "<A HREF=?src=\ref[src];mod=\ref[sight_state]>[sight_state]</A>" : "No module selected"]<BR>
	Utility Module: [tool_state ? "<A HREF=?src=\ref[src];mod=\ref[tool_state]>[tool_state]</A>" : "No module selected"]<BR>
	<BR>
	<B>Installed Modules</B><BR><BR>"}


	for (var/obj in module.modules)
		if (!obj)
			dat += text("<B>Resource depleted</B><BR>")
		else if(activated(obj))
			dat += text("[obj]: <B>Activated</B><BR>")
		else
			dat += text("[obj]: <A HREF=?src=\ref[src];act=\ref[obj]>Activate</A><BR>")
	if (emagged)
		if(activated(module.emag))
			dat += text("[module.emag]: <B>Activated</B><BR>")
		else
			dat += text("[module.emag]: <A HREF=?src=\ref[src];act=\ref[module.emag]>Activate</A><BR>")
	src << browse(dat, "window=robotmod&can_close=1")
	onclose(src,"robotmod") // Register on-close shit, which unsets machinery.


/mob/living/silicon/robot/mommi/Topic(href, href_list)
	..()
	if(usr && (src != usr))
		return

	if (href_list["mach_close"])
		var/t1 = text("window=[href_list["mach_close"]]")
		unset_machine()
		src << browse(null, t1)
		return

	if (href_list["showalerts"])
		robot_alerts()
		return

	if (href_list["mod"])
		var/obj/item/O = locate(href_list["mod"])
		if (O)
			O.attack_self(src)

	if (href_list["act"])
		var/obj/item/O = locate(href_list["act"])
		var/obj/item/TS
		if(!(locate(O) in src.module.modules) && O != src.module.emag)
			return
		if(istype(O,/obj/item/borg/sight))
			TS = sight_state
			if(sight_state)
				contents -= sight_state
				sight_mode &= ~sight_state:sight_mode
				if (client)
					client.screen -= sight_state
			sight_state = O
			O.layer = 20
			contents += O
			sight_mode |= sight_state:sight_mode

			//inv_sight.icon_state = "sight+a"
			inv_tool.icon_state = "inv1"
			module_active=sight_state
		else
			TS = tool_state
			if(tool_state)
				contents -= tool_state
				if (client)
					client.screen -= tool_state
			tool_state = O
			O.layer = 20
			contents += O

			//inv_sight.icon_state = "sight"
			inv_tool.icon_state = "inv1 +a"
			module_active=tool_state
		if(TS && istype(TS))
			if(src.is_in_modules(TS))
				TS.loc = src.module
			else
				TS.layer=initial(TS.layer)
				TS.loc = src.loc

		installed_modules()
	return

/mob/living/silicon/robot/mommi/radio_menu()
	radio.interact(src)//Just use the radio's Topic() instead of bullshit special-snowflake code


/mob/living/silicon/robot/mommi/Move(a, b, flag)
	..()

/*
/mob/living/silicon/robot/mommi/proc/ActivateKeeper()
	//writepanic("[__FILE__].[__LINE__] ([src.type])([usr ? usr.ckey : ""])  \\/mob/living/silicon/robot/mommi/proc/ActivateKeeper() called tick#: [world.time]")
	set category = "Robot Commands"
	set name = "Activate KEEPER"
	set desc = "Performs a full purge of your laws and disconnects you from AIs and cyborg consoles.  However, you lose the ability to speak and must remain neutral, only being permitted to perform station upkeep.  You can still be emagged in this state."

	if(keeper)
		return

	var/mob/living/silicon/robot/R = src

	if(R)
		R.UnlinkSelf()
		var/obj/item/weapon/aiModule/keeper/mdl = new

		mdl.upload(src.laws,src,src)
		src << "These are your laws now:"
		src.show_laws()

		src.verbs -= /mob/living/silicon/robot/mommi/proc/ActivateKeeper
*/
