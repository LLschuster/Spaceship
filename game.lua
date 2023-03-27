local composer = require("composer")

local scene = composer.newScene()

-- -----------------------------------------------------------------------------------
-- Code outside of the scene event functions below will only be executed ONCE unless
-- the scene is removed entirely (not recycled) via "composer.removeScene()"
-- -----------------------------------------------------------------------------------
local physics = require("physics")
physics.start()
physics.setGravity(0, 0)

-- Configure image sheet
local sheetOptions =
{
    -- can get all sizes with gimp;
    frames =
    {
        {
            -- 1) asteroid 1
            x = 0,
            y = 0,
            width = 102,
            height = 85
        },
        {
            -- 2) asteroid 2
            x = 0,
            y = 85,
            width = 90,
            height = 83
        },
        {
            -- 3) asteroid 3
            x = 0,
            y = 168,
            width = 100,
            height = 97
        },
        {
            -- 4) ship
            x = 0,
            y = 265,
            width = 98,
            height = 79
        },
        {
            -- 5) laser
            x = 98,
            y = 265,
            width = 14,
            height = 40
        },
    },
}

local objectSheet = graphics.newImageSheet("gameObjects.png", sheetOptions)


-- Initialize variables
local lives = 1
local score = 0
local died = false

local asteroidsTable = {}

local ship
local gameLoopTimer
local livesText
local scoreText

-- Set up display groups
local backGroup -- Display group for the background image
local mainGroup -- Display group for the ship, asteroids, lasers, etc.
local uiGroup-- Display group for UI objects like the score

local fireSound
local explosionSound
local musicTrack

local backgroundWidth = 800
local backgroundHeight = 1400

local function endGame()
    composer.setVariable("finalScore", score)
    composer.gotoScene( "highscores", { time=800, effect="crossFade" } )
end

local function updateText()
    livesText.text = "lives: " .. lives
    scoreText.text = "score: " .. score
end

local function createAsteroid()
    local newAsteroid = display.newImageRect(mainGroup, objectSheet, 1, 102, 85)
    table.insert(asteroidsTable, newAsteroid)
    physics.addBody(newAsteroid, "dynamic", { radius = 40, bounce = 0.8 })
    newAsteroid.myName = "asteroid"

    local whereFrom = math.random(3)
    if (whereFrom == 1) then
        -- from the left
        newAsteroid.x = -60
        newAsteroid.y = math.random(backgroundHeight * 0.4)
    elseif (whereFrom == 2) then
        -- from the top
        newAsteroid.x = math.random(display.contentWidth)
        newAsteroid.y = -60
    else
        -- from the right
        newAsteroid.x = display.contentWidth + 60
        newAsteroid.y = math.random(backgroundHeight * 0.4)
    end

    newAsteroid:setLinearVelocity(math.random(40, 120), math.random(20, 60))
    newAsteroid:applyTorque(math.random(-6, 6))
end

local function dragShip(event)
    local ship = event.target
    local phase = event.phase

    if (phase == "began") then
        display.currentStage:setFocus(ship)
        ship.touchOffsetX = event.x - ship.x
    elseif (phase == "moved") then
        ship.x = event.x - ship.touchOffsetX
    elseif (phase == "cancelled" or phase == "ended") then
        display.currentStage:setFocus(nil)
    end

    return true
end

local function restoreShip()
    ship.isBodyActive = false
    ship.x = display.contentCenterX
    ship.y = display.contentHeight - 100

    -- Fade in the ship
    transition.to(ship, {
        alpha = 1,
        time = 4000,
        onComplete = function()
            ship.isBodyActive = true
            died = false
        end
    })
end

local function onCollision(event)
    if (event.phase == "began") then
        local obj1 = event.object1
        local obj2 = event.object2

        if ((obj1.myName == "laser" and obj2.myName == "asteroid") or
            (obj2.myName == "laser" and obj1.myName == "asteroid")) then
            display.remove(obj1)
            display.remove(obj2)

            for i = #asteroidsTable, 1, -1 do
                if (obj1 == asteroidsTable[i] or obj2 == asteroidsTable[i]) then
                    table.remove(asteroidsTable, i)
                    break
                end
            end

            score = score + 1000
        elseif ((obj1.myName == "ship" and obj2.myName == "asteroid") or
            (obj1.myName == "asteroid" and obj2.myName == "ship"))
        then
            if (died == false) then
                died = true
                lives = lives - 1
                audio.play(explosionSound)

                if (lives <= 0) then
                    -- display.remove(ship)
                    endGame()
                else
                    ship.alpha = 0.2
                    timer.performWithDelay(300, restoreShip, 1)
                end
            end
        end
    end
end

local function fireLaser()
    local newLaser = display.newImageRect(mainGroup, objectSheet, 5, 14, 40)
    physics.addBody(newLaser, "dynamic", { isSensor = true })
    newLaser.isBullet = true
    newLaser.myName = "laser"

    newLaser.x = ship.x
    newLaser.y = ship.y
    newLaser:toBack()

    audio.play(fireSound)
    transition.to(newLaser, { y = -40, time = 500, onComplete = function() display.remove(newLaser) end })
end

local function gameLoop()
    createAsteroid()

    for i = #asteroidsTable, 1, -1 do
        local asteroid = asteroidsTable[i]
        if (asteroid.x <= -100 or asteroid.x >= display.contentWidth + 100
            or asteroid.y <= -100 or asteroid.y >= display.contentHeight + 100) then
            display.remove(asteroid)
            table.remove(asteroidsTable, i)
        end
    end

    updateText()
end


-- -----------------------------------------------------------------------------------
-- Scene event functions
-- -----------------------------------------------------------------------------------

-- create()
function scene:create(event)
    local sceneGroup = self.view

    physics.pause()

    -- Set up display groups
    backGroup = display.newGroup()
    mainGroup = display.newGroup()
    uiGroup = display.newGroup()

    sceneGroup:insert(backGroup)
    sceneGroup:insert(mainGroup)
    sceneGroup:insert(uiGroup)
    -- Code here runs when the scene is first created but has not yet appeared on screen

    local background = display.newImageRect(backGroup, "background.png", backgroundWidth, backgroundHeight)
    background.x = display.contentCenterX
    background.y = display.contentCenterY

    ship = display.newImageRect(mainGroup, objectSheet, 4, 98, 79)
    ship.x = display.contentCenterX
    ship.y = display.contentHeight - 100
    physics.addBody(ship, { radius = 30, isSensor = true })
    ship.myName = "ship"

    print("content center x " .. display.contentCenterX)
    print("origin  x " .. display.safeScreenOriginX)
    print("viewable " .. display.viewableContentWidth)

    livesText = display.newText({
        parent = uiGroup,
        text = "lives: " .. lives,
        font = native.SystemFont,
        x = display.contentCenterX - 100,
        y = 80,
        fontSize = 36
    })
    scoreText = display.newText({
        parent = uiGroup,
        text = "score: " .. score,
        font = native.SystemFont,
        x = display.contentCenterX + 100,
        y = 80,
        fontSize = 36
    })

    explosionSound = audio.loadSound( "audio/explosion.wav" )
    fireSound = audio.loadSound( "audio/fire.wav" )
    musicTrack = audio.loadStream( "audio/80s-Space-Game_Looping.wav")

    ship:addEventListener("tap", fireLaser)
    ship:addEventListener("touch", dragShip)
end

-- show()
function scene:show(event)
    local sceneGroup = self.view
    local phase = event.phase

    if (phase == "will") then
        -- Code here runs when the scene is still off screen (but is about to come on screen)
    elseif (phase == "did") then
        -- Code here runs when the scene is entirely on screen
        physics.start()
        gameLoopTimer = timer.performWithDelay(500, gameLoop, 0)
        Runtime:addEventListener("collision", onCollision)
        audio.play( musicTrack )
    end
end

-- hide()
function scene:hide(event)
    local sceneGroup = self.view
    local phase = event.phase

    physics.pause()

    if (phase == "will") then
        -- Code here runs when the scene is on screen (but is about to go off screen)
        timer.cancel(gameLoopTimer)
    elseif (phase == "did") then
        -- Code here runs immediately after the scene goes entirely off screen
        Runtime:removeEventListener("collision", onCollision)
        composer.removeScene("game")
    end
end

-- destroy()
function scene:destroy(event)
    local sceneGroup = self.view
    -- Code here runs prior to the removal of scene's view
end

-- -----------------------------------------------------------------------------------
-- Scene event function listeners
-- -----------------------------------------------------------------------------------
scene:addEventListener("create", scene)
scene:addEventListener("show", scene)
scene:addEventListener("hide", scene)
scene:addEventListener("destroy", scene)
-- -----------------------------------------------------------------------------------

return scene
