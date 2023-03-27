local composer = require( "composer" )
 
-- Hide status bar
display.setStatusBar( display.HiddenStatusBar )
 
-- Seed the random number generator
math.randomseed( os.time() )
 
audio.reserveChannels(1)
audio.setVolume( 0.5, { channel=1 } )
-- Go to the menu screen
composer.gotoScene( "menu" )