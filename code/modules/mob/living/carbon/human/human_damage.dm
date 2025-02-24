//Updates the mob's health from organs and mob damage variables
/mob/living/carbon/human/updatehealth()

	if(status_flags & GODMODE)
		health = maxHealth
		set_stat(CONSCIOUS)
		return

	health = maxHealth - getBrainLoss()

	//TODO: fix husking
	if(((maxHealth - getFireLoss()) < config.health_threshold_dead) && stat == DEAD)
		ChangeToHusk()
	return

/mob/living/carbon/human/adjustBrainLoss(var/amount)
	if(status_flags & GODMODE)	return 0	//godmode
	if(should_have_organ(BP_BRAIN))
		var/obj/item/organ/internal/brain/sponge = get_organ(BP_BRAIN)
		if(sponge)
			sponge.take_internal_damage(amount)

/mob/living/carbon/human/setBrainLoss(var/amount)
	if(status_flags & GODMODE)	return 0	//godmode
	if(should_have_organ(BP_BRAIN))
		var/obj/item/organ/internal/brain/sponge = get_organ(BP_BRAIN)
		if(sponge)
			sponge.damage = min(max(amount, 0),sponge.species.total_health)
			updatehealth()

/mob/living/carbon/human/getBrainLoss()
	if(status_flags & GODMODE)	return 0	//godmode
	if(should_have_organ(BP_BRAIN))
		var/obj/item/organ/internal/brain/sponge = get_organ(BP_BRAIN)
		if(sponge)
			if(sponge.status & ORGAN_DEAD)
				return sponge.species.total_health
			else
				return sponge.damage
		else
			return species.total_health
	return 0

//Straight pain values, not affected by painkillers etc
/mob/living/carbon/human/getHalLoss()
	var/amount = 0
	for(var/obj/item/organ/external/E in get_external_organs())
		amount += E.get_pain()
	return amount

/mob/living/carbon/human/setHalLoss(var/amount)
	adjustHalLoss(getHalLoss()-amount)

/mob/living/carbon/human/adjustHalLoss(var/amount)
	var/heal = (amount < 0)
	amount = abs(amount)
	var/list/limbs = get_external_organs()
	if(LAZYLEN(limbs))
		var/list/pick_organs = limbs.Copy()
		while(amount > 0 && pick_organs.len)
			var/obj/item/organ/external/E = pick(pick_organs)
			pick_organs -= E
			if(!istype(E))
				continue

			if(heal)
				amount -= E.remove_pain(amount)
			else
				amount -= E.add_pain(amount)
	BITSET(hud_updateflag, HEALTH_HUD)

//These procs fetch a cumulative total damage from all organs
/mob/living/carbon/human/getBruteLoss()
	var/amount = 0
	for(var/obj/item/organ/external/O in get_external_organs())
		if(BP_IS_PROSTHETIC(O) && !O.vital)
			continue //robot limbs don't count towards shock and crit
		amount += O.brute_dam
	return amount

/mob/living/carbon/human/getFireLoss()
	var/amount = 0
	for(var/obj/item/organ/external/O in get_external_organs())
		if(BP_IS_PROSTHETIC(O) && !O.vital)
			continue //robot limbs don't count towards shock and crit
		amount += O.burn_dam
	return amount

/mob/living/carbon/human/adjustBruteLoss(var/amount)
	if(amount > 0)
		take_overall_damage(amount, 0)
	else
		heal_overall_damage(-amount, 0)
	BITSET(hud_updateflag, HEALTH_HUD)

/mob/living/carbon/human/adjustFireLoss(var/amount)
	if(amount > 0)
		take_overall_damage(0, amount)
	else
		heal_overall_damage(0, -amount)
	BITSET(hud_updateflag, HEALTH_HUD)

/mob/living/carbon/human/getCloneLoss()
	var/amount = 0
	for(var/obj/item/organ/external/E in get_external_organs())
		amount += E.get_genetic_damage()
	return amount

/mob/living/carbon/human/setCloneLoss(var/amount)
	adjustCloneLoss(getCloneLoss()-amount)

/mob/living/carbon/human/adjustCloneLoss(var/amount)
	var/heal = amount < 0
	amount = abs(amount)
	var/list/limbs = get_external_organs()
	if(LAZYLEN(limbs))
		var/list/pick_organs = limbs.Copy()
		while(amount > 0 && pick_organs.len)
			var/obj/item/organ/external/E = pick(pick_organs)
			pick_organs -= E
			if(heal)
				amount -= E.remove_genetic_damage(amount)
			else
				amount -= E.add_genetic_damage(amount)
	BITSET(hud_updateflag, HEALTH_HUD)

// Defined here solely to take species flags into account without having to recast at mob/living level.
/mob/living/carbon/human/getOxyLoss()
	if(!need_breathe())
		return 0
	else
		var/obj/item/organ/internal/lungs/breathe_organ = get_organ(species.breathing_organ)
		if(!breathe_organ)
			return maxHealth/2
		return breathe_organ.get_oxygen_deprivation()

/mob/living/carbon/human/setOxyLoss(var/amount)
	if(!need_breathe())
		return 0
	else
		adjustOxyLoss(getOxyLoss()-amount)

/mob/living/carbon/human/adjustOxyLoss(var/amount)
	if(!need_breathe())
		return
	var/heal = amount < 0
	var/obj/item/organ/internal/lungs/breathe_organ = get_organ(species.breathing_organ)
	if(breathe_organ)
		if(heal)
			breathe_organ.remove_oxygen_deprivation(abs(amount))
		else
			breathe_organ.add_oxygen_deprivation(abs(amount*species.oxy_mod))
	BITSET(hud_updateflag, HEALTH_HUD)

/mob/living/carbon/human/getToxLoss()
	if((species.species_flags & SPECIES_FLAG_NO_POISON) || isSynthetic())
		return 0
	var/amount = 0
	for(var/obj/item/organ/internal/I in get_internal_organs())
		amount += I.getToxLoss()
	return amount

/mob/living/carbon/human/setToxLoss(var/amount)
	if(!(species.species_flags & SPECIES_FLAG_NO_POISON) && !isSynthetic())
		adjustToxLoss(getToxLoss()-amount)

// TODO: better internal organ damage procs.
/mob/living/carbon/human/adjustToxLoss(var/amount)

	if((species.species_flags & SPECIES_FLAG_NO_POISON) || isSynthetic())
		return

	var/heal = amount < 0
	amount = abs(amount)

	if (!heal)
		amount = amount * species.get_toxins_mod(src)
		var/antitox = GET_CHEMICAL_EFFECT(src, CE_ANTITOX)
		if(antitox)
			amount *= 1 - antitox * 0.25

	var/list/pick_organs = get_internal_organs()
	if(!LAZYLEN(pick_organs))
		return
	pick_organs = shuffle(pick_organs.Copy())

	// Prioritize damaging our filtration organs first.
	var/obj/item/organ/internal/kidneys/kidneys = get_organ(BP_KIDNEYS)
	if(kidneys)
		pick_organs -= kidneys
		pick_organs.Insert(1, kidneys)
	var/obj/item/organ/internal/liver/liver = get_organ(BP_LIVER)
	if(liver)
		pick_organs -= liver
		pick_organs.Insert(1, liver)

	// Move the brain to the very end since damage to it is vastly more dangerous
	// (and isn't technically counted as toxloss) than general organ damage.
	var/obj/item/organ/internal/brain/brain = get_organ(BP_BRAIN)
	if(brain)
		pick_organs -= brain
		pick_organs += brain

	for(var/internal in pick_organs)
		var/obj/item/organ/internal/I = internal
		if(amount <= 0)
			break
		if(heal)
			if(I.damage < amount)
				amount -= I.damage
				I.damage = 0
			else
				I.damage -= amount
				amount = 0
		else
			var/cap_dam = I.max_damage - I.damage
			if(amount >= cap_dam)
				I.take_internal_damage(cap_dam, silent=TRUE)
				amount -= cap_dam
			else
				I.take_internal_damage(amount, silent=TRUE)
				amount = 0

/mob/living/carbon/human/proc/can_autoheal(var/dam_type)
	if(!species || !dam_type) return FALSE

	if(dam_type == BRUTE)
		return(getBruteLoss() < species.total_health / 2)
	else if(dam_type == BURN)
		return(getFireLoss() < species.total_health / 2)
	return FALSE

////////////////////////////////////////////

//Returns a list of damaged organs
/mob/living/carbon/human/proc/get_damaged_organs(var/brute, var/burn)
	var/list/obj/item/organ/external/parts = list()
	for(var/obj/item/organ/external/O in get_external_organs())
		if((brute && O.brute_dam) || (burn && O.burn_dam))
			parts += O
	return parts

//Returns a list of damageable organs
/mob/living/carbon/human/proc/get_damageable_organs()
	var/list/obj/item/organ/external/parts = list()
	for(var/obj/item/organ/external/O in get_external_organs())
		if(O.is_damageable())
			parts += O
	return parts

//Heals ONE external organ, organ gets randomly selected from damaged ones.
//It automatically updates damage overlays if necesary
//It automatically updates health status
/mob/living/carbon/human/heal_organ_damage(var/brute, var/burn, var/affect_robo = FALSE)
	var/list/obj/item/organ/external/parts = get_damaged_organs(brute,burn)
	if(!parts.len)	return
	var/obj/item/organ/external/picked = pick(parts)
	if(picked.heal_damage(brute,burn,robo_repair = affect_robo))
		BITSET(hud_updateflag, HEALTH_HUD)
	updatehealth()


//TODO reorganize damage procs so that there is a clean API for damaging living mobs

/*
In most cases it makes more sense to use apply_damage() instead! And make sure to check armour if applicable.
*/
//Damages ONE external organ, organ gets randomly selected from damagable ones.
//It automatically updates damage overlays if necesary
//It automatically updates health status
/mob/living/carbon/human/take_organ_damage(var/brute = 0, var/burn = 0, var/bypass_armour = FALSE, var/override_droplimb)
	var/list/parts = get_damageable_organs()
	if(length(parts))
		var/obj/item/organ/external/picked = pick(parts)
		if(picked.take_external_damage(brute, burn, override_droplimb = override_droplimb))
			BITSET(hud_updateflag, HEALTH_HUD)
		updatehealth()

//Heal MANY external organs, in random order
/mob/living/carbon/human/heal_overall_damage(var/brute, var/burn)
	var/list/obj/item/organ/external/parts = get_damaged_organs(brute,burn)

	while(parts.len && (brute>0 || burn>0) )
		var/obj/item/organ/external/picked = pick(parts)

		var/brute_was = picked.brute_dam
		var/burn_was = picked.burn_dam

		picked.heal_damage(brute,burn)

		brute -= (brute_was-picked.brute_dam)
		burn -= (burn_was-picked.burn_dam)

		parts -= picked
	updatehealth()
	BITSET(hud_updateflag, HEALTH_HUD)

// damage MANY external organs, in random order
/mob/living/carbon/human/take_overall_damage(var/brute, var/burn, var/sharp = 0, var/edge = 0, var/used_weapon = null)
	if(status_flags & GODMODE)	return	//godmode
	var/list/obj/item/organ/external/parts = get_damageable_organs()
	if(!parts.len) return

	var/dam_flags = (sharp? DAM_SHARP : 0)|(edge? DAM_EDGE : 0)
	var/brute_avg = brute / parts.len
	var/burn_avg = burn / parts.len
	for(var/obj/item/organ/external/E in parts)
		if(QDELETED(E))
			continue
		if(E.owner != src)
			continue // The code below may affect the children of an organ.

		if(brute_avg)
			apply_damage(damage = brute_avg, damagetype = BRUTE, damage_flags = dam_flags, used_weapon = used_weapon, silent = TRUE, given_organ = E)
		if(burn_avg)
			apply_damage(damage = burn_avg, damagetype = BURN, damage_flags = dam_flags, used_weapon = used_weapon, silent = TRUE, given_organ = E)

	updatehealth()
	BITSET(hud_updateflag, HEALTH_HUD)

/*
This function restores all organs.
*/
/mob/living/carbon/human/restore_all_organs(var/ignore_prosthetic_prefs)
	species?.create_missing_organs(src)
	for(var/bodypart in global.all_limb_tags_by_depth)
		var/obj/item/organ/external/current_organ = get_organ(bodypart)
		if(istype(current_organ))
			current_organ.rejuvenate(ignore_prosthetic_prefs)
	bad_external_organs.Cut() // otherwise hanging refs will prevent gc after rejuv
	verbs -= /mob/living/carbon/human/proc/undislocate

/mob/living/carbon/human/proc/HealDamage(zone, brute, burn)
	var/obj/item/organ/external/E = get_organ(zone)
	if(istype(E, /obj/item/organ/external))
		if (E.heal_damage(brute, burn))
			BITSET(hud_updateflag, HEALTH_HUD)
	else
		return 0
	return

/mob/living/carbon/human/apply_damage(var/damage = 0, var/damagetype = BRUTE, var/def_zone = null, var/damage_flags = 0, var/obj/used_weapon = null, var/armor_pen, var/silent = FALSE, var/obj/item/organ/external/given_organ = null)

	var/obj/item/organ/external/organ = given_organ
	if(!organ)
		if(isorgan(def_zone))
			organ = def_zone
		else
			if(!def_zone)
				if(damage_flags & DAM_DISPERSED)
					var/old_damage = damage
					var/tally
					silent = TRUE // Will damage a lot of organs, probably, so avoid spam.
					for(var/zone in organ_rel_size)
						tally += organ_rel_size[zone]
					for(var/zone in organ_rel_size)
						damage = old_damage * organ_rel_size[zone]/tally
						def_zone = zone
						. = .() || .
					return
				def_zone = ran_zone(def_zone, target = src)
			organ = get_organ(check_zone(def_zone, src))

	//Handle other types of damage
	if(!(damagetype in list(BRUTE, BURN, PAIN, CLONE)))
		return ..()
	if(!istype(organ))
		return 0 // This is reasonable and means the organ is missing.

	handle_suit_punctures(damagetype, damage, def_zone)

	var/list/after_armor = modify_damage_by_armor(def_zone, damage, damagetype, damage_flags, src, armor_pen, silent)
	damage = after_armor[1]
	damagetype = after_armor[2]
	damage_flags = after_armor[3]
	if(!damage)
		return 0

	if(damage > 15 && prob(damage*4) && organ.can_feel_pain())
		make_reagent(round(damage/10), /decl/material/liquid/adrenaline)
	var/datum/wound/created_wound
	damageoverlaytemp = 20
	switch(damagetype)
		if(BRUTE)
			created_wound = organ.take_external_damage(damage, 0, damage_flags, used_weapon)
		if(BURN)
			created_wound = organ.take_external_damage(0, damage, damage_flags, used_weapon)
		if(PAIN)
			organ.add_pain(damage)
		if(CLONE)
			organ.add_genetic_damage(damage)

	// Will set our damageoverlay icon to the next level, which will then be set back to the normal level the next mob.Life().
	updatehealth()
	BITSET(hud_updateflag, HEALTH_HUD)
	return created_wound

// Find out in how much pain the mob is at the moment.
/mob/living/carbon/human/proc/get_shock()

	if (!can_feel_pain())
		return 0

	var/traumatic_shock = getHalLoss()
	traumatic_shock -= GET_CHEMICAL_EFFECT(src, CE_PAINKILLER)

	if(stat == UNCONSCIOUS)
		traumatic_shock *= 0.6
	return max(0,traumatic_shock)

//Electrical shock

/mob/living/carbon/human/apply_shock(var/shock_damage, var/def_zone, var/base_siemens_coeff = 1.0)
	var/obj/item/organ/external/initial_organ = get_organ(check_zone(def_zone, src))
	if(!initial_organ)
		initial_organ = pick(get_external_organs())

	var/obj/item/organ/external/floor_organ

	if(!lying)
		var/list/obj/item/organ/external/standing = list()
		for(var/limb_tag in list(BP_L_FOOT, BP_R_FOOT))
			var/obj/item/organ/external/E = get_organ(limb_tag)
			if(E && E.is_usable())
				standing[E.organ_tag] = E
		if((def_zone == BP_L_FOOT || def_zone == BP_L_LEG) && standing[BP_L_FOOT])
			floor_organ = standing[BP_L_FOOT]
		if((def_zone == BP_R_FOOT || def_zone == BP_R_LEG) && standing[BP_R_FOOT])
			floor_organ = standing[BP_R_FOOT]
		else
			floor_organ = standing[pick(standing)]

	if(!floor_organ)
		floor_organ = pick(get_external_organs())

	var/list/obj/item/organ/external/to_shock = trace_shock(initial_organ, floor_organ)

	if(to_shock && to_shock.len)
		shock_damage /= to_shock.len
		shock_damage = round(shock_damage, 0.1)
	else
		return 0

	var/total_damage = 0

	for(var/obj/item/organ/external/E in to_shock)
		total_damage += ..(shock_damage, E.organ_tag, base_siemens_coeff * get_siemens_coefficient_organ(E))

	if(total_damage > 10)
		local_emp(initial_organ, 3)

	return total_damage

/mob/living/carbon/human/proc/trace_shock(var/obj/item/organ/external/init, var/obj/item/organ/external/floor)
	var/list/obj/item/organ/external/traced_organs = list(floor)

	if(!init)
		return

	if(!floor || init == floor)
		return list(init)

	for(var/obj/item/organ/external/E in list(floor, init))
		while(E && E.parent_organ)
			var/candidate = get_organ(E.parent_organ)
			if(!candidate || (candidate in traced_organs))
				break // Organ parenthood is not guaranteed to be a tree
			E = candidate
			traced_organs += E
			if(E == init)
				return traced_organs

	return traced_organs

/mob/living/carbon/human/proc/local_emp(var/list/limbs, var/severity = 2)
	if(!islist(limbs))
		limbs = list(limbs)

	var/list/EMP = list()
	for(var/obj/item/organ/external/limb in limbs)
		EMP += limb
		if(LAZYLEN(limb.internal_organs))
			EMP += limb.internal_organs
		if(LAZYLEN(limb.implants))
			EMP += limb.implants
	for(var/atom/E in EMP)
		E.emp_act(severity)
