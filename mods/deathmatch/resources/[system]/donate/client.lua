function playDonateSound()
	playSound("sound.mp3")
end
addEvent("playDonateSound", true)
addEventHandler("playDonateSound", resourceRoot, playDonateSound)