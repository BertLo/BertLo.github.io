module Home exposing (main)

import Touch
import AnimationFrame
import SingleTouch
import Json.Decode as Json
import Html exposing (Html, div, text, a, hr)
import Html.Attributes exposing (class, href, target)
import Html.Events exposing (on)
import Svg exposing (svg, line, linearGradient, stop)
import Svg.Attributes exposing (x1, x2, y1, y2, stroke, height, width, offset, id, style)
import List
import Window
import Time exposing (Time)
import Mouse exposing (Position)
import Task exposing (perform)
import Random exposing (float, int, map4)
import Navigation exposing (load)


main =
    Html.program { init = init, view = view, update = update, subscriptions = subscriptions }



-- MODEL


type alias Meteor =
    { x : Int
    , y : Int
    , current : Int
    , end : Int
    , depth : Int
    }


type alias Model =
    { meteors : List Meteor
    , windowWidth : Int
    , windowHeight : Int
    , mouseX : Int
    , mouseY : Int
    , originX : Int
    , originY : Int
    , holding : Bool
    }


init : ( Model, Cmd Msg )
init =
    ( { meteors = []
      , windowWidth = 0
      , windowHeight = 0
      , mouseX = 0
      , mouseY = 0
      , originX = 0
      , originY = 0
      , holding = False
      }
    , perform Resize Window.size
    )



-- UPDATE


type Msg
    = Wheel
    | Prob Float
    | Add Meteor
    | Resize Window.Size
    | Move Position
    | Pan Touch.Coordinates
    | Hold Touch.Coordinates
    | Lift Touch.Coordinates
    | Tick Time
    | Github Touch.Coordinates
    | Linkedin Touch.Coordinates
    | Resume Touch.Coordinates


lineOffset meteor height =
    height - meteor.y - meteor.x


tailLength =
    85


progress current end =
    if current < end then
        current + 6
    else
        current + 2


progressMeteors : List Meteor -> List Meteor
progressMeteors model =
    List.map (\m -> { m | current = progress m.current m.end }) model
        |> List.filter (\m -> m.current < m.end + tailLength)


minLength =
    240


maxLength =
    450


maxDepth =
    4


github =
    "https://github.com/BertLo"


linkedin =
    "https://www.linkedin.com/in/alberthtlo"


resume =
    "/resume"


newMeteor : Int -> Int -> Cmd Msg
newMeteor windowWidth windowHeight =
    map4 (\x y end depth -> Meteor x y 0 end depth) (int maxLength windowWidth) (int 0 (windowHeight - maxLength)) (int minLength maxLength) (int 1 maxDepth)
        |> Random.generate Add


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        maxMeteors =
            10

        shower =
            ( { model | meteors = progressMeteors model.meteors }, Random.generate Prob (float 0 1) )
    in
        case msg of
            Wheel ->
                shower

            Prob p ->
                if p < (((toFloat (maxMeteors - (List.length model.meteors))) / (toFloat maxMeteors)) ^ 2) then
                    ( model, newMeteor model.windowWidth model.windowHeight )
                else
                    ( model, Cmd.none )

            Add new ->
                let
                    shouldAdd =
                        List.all (\m -> abs ((lineOffset m model.windowHeight) - (lineOffset new model.windowHeight)) > 50) model.meteors
                in
                    if shouldAdd then
                        ( { model | meteors = model.meteors ++ [ new ] }, Cmd.none )
                    else
                        ( model, Cmd.none )

            Resize size ->
                ( { model
                    | windowWidth = size.width
                    , windowHeight = size.height
                  }
                , Cmd.none
                )

            Move pos ->
                ( { model
                    | mouseX = pos.x
                    , mouseY = pos.y
                  }
                , Cmd.none
                )

            Pan coordinates ->
                ( { model
                    | mouseX = model.originX - (round coordinates.clientX)
                    , mouseY = model.originY - (round coordinates.clientY)
                  }
                , Cmd.none
                )

            Hold coordinates ->
                ( { model
                    | holding = True
                    , originX = round coordinates.clientX
                    , originY = round coordinates.clientY
                  }
                , Cmd.none
                )

            Lift coordinates ->
                ( { model
                    | holding = False
                  }
                , Cmd.none
                )

            Tick time ->
                if model.holding then
                    shower
                else
                    ( model, Cmd.none )

            Github coordinates ->
                ( model, load github )

            Linkedin coordinates ->
                ( model, load linkedin )

            Resume coordinates ->
                ( model, load resume )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch [ Window.resizes Resize, Mouse.moves Move, AnimationFrame.times Tick ]



-- VIEW


onWheel : msg -> Html.Attribute msg
onWheel message =
    on "wheel" (Json.succeed message)


stopPoint current end =
    if current >= end then
        toString (tailLength - (current - end))
    else
        toString tailLength


perspectiveOffset : Int -> Int -> Float
perspectiveOffset mouse window =
    let
        maxOffset =
            100
    in
        ((((toFloat window) / 2.0) - (toFloat mouse)) / (toFloat window)) * maxOffset


depthOffset : Int -> Float -> Int -> Int
depthOffset org offset depth =
    org + (round (offset * (1.0 / (toFloat depth))))


view : Model -> Html.Html Msg
view model =
    let
        xOffset =
            perspectiveOffset model.mouseX model.windowWidth

        yOffset =
            perspectiveOffset model.mouseY model.windowHeight
    in
        div [ class "Elm-Home", onWheel Wheel, SingleTouch.onStart Hold, SingleTouch.onEnd Lift, SingleTouch.onMove Pan ]
            [ svg [ width "100%", height "100%" ]
                ((List.indexedMap
                    (\i m ->
                        (linearGradient
                            [ id ("gradient" ++ (toString i))
                            , x1 "0%"
                            , y1 "0%"
                            , x2 "100%"
                            , y2 "0%"
                            ]
                            [ stop [ offset "0%", style "stop-color: rgb(255, 255, 255); stop-opacity: 1" ] []
                            , stop [ offset ((stopPoint m.current m.end) ++ "%"), style "stop-color: rgb(255, 255, 255); stop-opacity:0" ] []
                            ]
                        )
                    )
                    model.meteors
                 )
                    ++ (List.indexedMap
                            (\i m ->
                                (line
                                    [ x1 (toString (depthOffset m.x xOffset m.depth))
                                    , y1 (toString (depthOffset m.y yOffset m.depth))
                                    , x2 (toString (depthOffset (m.x - (min m.current m.end)) xOffset m.depth))
                                    , y2 (toString (depthOffset (m.y + (min m.current m.end)) yOffset m.depth))
                                    , stroke ("url(#gradient" ++ (toString i) ++ ")")
                                    ]
                                    []
                                )
                            )
                            model.meteors
                       )
                )
            , div [ class "text" ]
                [ div [ class "name" ] [ text "Albert Lo" ]
                , div [ class "primary" ]
                    [ a [ href "https://xkcd.com/844/", target "_blank" ] [ text "software engineer" ]
                    , text " / "
                    , a [ href "https://xkcd.com/1678/", target "_blank" ] [ text "generalist" ]
                    ]
                , div [ class "secondary" ]
                    [ a [ href "https://xkcd.com/1537/", target "_blank" ] [ text "js enthusiast" ]
                    , text " / "
                    , a [ href "https://xkcd.com/1270/", target "_blank" ] [ text "lambda fanatic" ]
                    ]
                , hr [] []
                , div [ class "links" ]
                    [ a [ href github, target "_blank", SingleTouch.onStart Github ] [ text "github" ]
                    , text " / "
                    , a [ href linkedin, target "_blank", SingleTouch.onStart Linkedin ] [ text "linkedin" ]
                    , text " / "
                    , a [ href resume, target "_blank", SingleTouch.onStart Resume ] [ text "resume" ]
                    ]
                ]
            ]
