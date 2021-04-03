module Main exposing (main)

import Browser
import Browser.Events
import Color
import Element exposing (Attribute, Element)
import Element.Background as Background
import Element.Border as Border
import Element.Events as Events
import Element.Font as Font
import Element.Region as Region
import ElmLogo
import Html exposing (Html)
import Html.Attributes as HtmlAttr
import Http
import Json.Decode as Decode exposing (Decoder)
import List.Extra as List
import Maybe.Extra as Maybe
import Plot
import Regex exposing (Regex)
import Svg.Attributes as SvgAttr
import VerbalExpressions as VerEx


main : Program Flags Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }



-- MODEL


type alias Model =
    { users : RemoteData Users
    , channels : RemoteData (List Channel)
    , hoveredBar : Maybe Plot.Point
    , windowSize : WindowSize
    }


initialModel : Flags -> Model
initialModel { width, height } =
    { users = Loading
    , channels = Loading
    , hoveredBar = Nothing
    , windowSize =
        { width = width
        , height = height
        }
    }


type alias WindowSize =
    { width : Int
    , height : Int
    }


type alias Flags =
    { width : Int
    , height : Int
    }


type RemoteData a
    = Loading
    | Error
    | Data a


data : RemoteData a -> Maybe a
data remoteData =
    case remoteData of
        Loading ->
            Nothing

        Error ->
            Nothing

        Data a ->
            Just a


type alias TimeZone =
    { number : Float
    , timeZone : Float
    }


timeZoneDecoder : Decoder TimeZone
timeZoneDecoder =
    Decode.map2 TimeZone
        (Decode.field "number" Decode.float)
        (Decode.field "timeZone" Decode.float)


timeZonesDecoder : Decoder (List TimeZone)
timeZonesDecoder =
    Decode.field "timeZones" (Decode.list timeZoneDecoder)


type alias Users =
    { number : String
    , timeZones : List TimeZone
    }


usersDecoder : Decoder Users
usersDecoder =
    Decode.map2 Users
        (Decode.field "total" Decode.string)
        timeZonesDecoder


type alias Channel =
    { id : String
    , name : String
    , topic : String
    , members : Int
    }


channelDecoder : Decoder Channel
channelDecoder =
    Decode.map4 Channel
        (Decode.field "id" Decode.string)
        (Decode.field "name" Decode.string)
        (Decode.field "topic" Decode.string)
        (Decode.field "members" Decode.int)


channelsDecoder : Decoder (List Channel)
channelsDecoder =
    Decode.field "entries" (Decode.list channelDecoder)


init : Flags -> ( Model, Cmd Msg )
init flags =
    ( initialModel flags, Cmd.batch [ requestUsers, requestChannels ] )



--UPDATE


type Msg
    = NoOp
    | RequestUsers
    | UsersRequested (Result Http.Error Users)
    | RequestChannels
    | ChannelsRequested (Result Http.Error (List Channel))
    | BarHovered (Maybe Plot.Point)
    | WindowSizeChanged Int Int


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model
            , Cmd.none
            )

        RequestUsers ->
            ( { model | users = Loading }
            , requestUsers
            )

        UsersRequested (Ok users) ->
            ( { model | users = Data users }
            , Cmd.none
            )

        UsersRequested (Err _) ->
            ( { model | users = Error }
            , Cmd.none
            )

        RequestChannels ->
            ( { model | channels = Loading }
            , requestChannels
            )

        ChannelsRequested (Ok channels) ->
            ( { model | channels = Data channels }
            , Cmd.none
            )

        ChannelsRequested (Err _) ->
            ( { model | channels = Error }
            , Cmd.none
            )

        BarHovered hoveredBar ->
            ( { model | hoveredBar = hoveredBar }
            , Cmd.none
            )

        WindowSizeChanged width height ->
            ( { model | windowSize = WindowSize width height }
            , Cmd.none
            )


requestUsers : Cmd Msg
requestUsers =
    requestFirebase "users" usersDecoder UsersRequested


requestChannels : Cmd Msg
requestChannels =
    requestFirebase "channels" channelsDecoder ChannelsRequested


requestFirebase : String -> Decoder a -> (Result Http.Error a -> msg) -> Cmd msg
requestFirebase document decoder toMsg =
    Http.get
        { url = "https://us-central1-elm-lang-slack.cloudfunctions.net/getData?document=" ++ document
        , expect = Http.expectJson toMsg decoder
        }



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Browser.Events.onResize WindowSizeChanged



--VIEW


view : Model -> Html Msg
view model =
    Element.layout
        [ Font.family
            [ Font.external
                { name = "Source Sans Pro"
                , url = "https://fonts.googleapis.com/css?family=Source+Sans+Pro:400,700,400italic,700italic"
                }
            , Font.typeface "Trebuchet MS"
            , Font.typeface "Lucida Grande"
            , Font.typeface "Bitstream Vera Sans"
            , Font.typeface "Helvetica Neue"
            , Font.sansSerif
            ]
        , Font.color (Element.rgb255 41 60 75)
        , Font.size 24
        , Font.center
        , Background.color (Element.rgb255 255 255 255)
        , Element.paddingXY 15 100
        ]
        (Element.column
            [ Element.width Element.fill
            , Element.spacing 100
            , Element.centerX
            ]
            [ viewHeader model.users
            , viewChannels model.channels
            , viewTimeZones model.users model.hoveredBar model.windowSize
            , viewFooter
            ]
        )


viewHeader : RemoteData Users -> Element msg
viewHeader remoteData =
    let
        usersNumber =
            Maybe.unwrap "" .number (data remoteData)
    in
    Element.column
        [ Element.width Element.fill
        , Element.spacing 50
        , Element.centerX
        ]
        [ Element.el [ Element.centerX ] (ElmLogo.element 70)
        , Element.el
            [ Region.heading 1
            , Font.size 120
            , Element.centerY
            , Element.centerX
            ]
            (Element.text "elm")
        , Element.paragraph [] [ Element.text ("We are a community of " ++ usersNumber ++ " Elm language developers from all over the world.") ]
        , Element.paragraph [] [ Element.text "Join us and talk on Slack!" ]
        , Element.el [ Element.centerX ] <|
            viewButton "http://elmlang.herokuapp.com/" "Join Now"
        , Element.paragraph [ Element.centerX ] [ viewLink elmSlack "Already a member? Sign in here." ]
        ]


viewChannels : RemoteData (List Channel) -> Element Msg
viewChannels remoteData =
    case remoteData of
        Loading ->
            viewLoading "Channels"

        Error ->
            viewTryAgain RequestChannels

        Data channels ->
            Element.column
                [ Font.alignLeft
                , Element.spacing 50
                , Element.centerX
                , Element.width Element.shrink
                , Element.htmlAttribute (HtmlAttr.style "max-width" "600px")
                ]
                (viewTitle "Channels" :: List.map viewChannel channels)


viewChannel : Channel -> Element msg
viewChannel channel =
    Element.column [ Element.spacing 10 ]
        [ Element.paragraph [] [ viewBoldLink (elmSlack ++ "messages/" ++ channel.id) ("#" ++ channel.name) ]
        , viewTopic channel.topic
        , Element.paragraph []
            [ Element.el [ Font.color (Element.rgb255 96 181 204), Font.bold ] (Element.text (String.fromInt channel.members))
            , Element.text " "
            , Element.el [ Font.color (Element.rgb255 187 187 187) ] (Element.text "members")
            ]
        ]


viewTopic : String -> Element msg
viewTopic topic =
    let
        regex =
            Regex.fromString "\\s"
                |> Maybe.withDefault Regex.never
    in
    topic
        |> Regex.split regex
        |> List.map viewTopicPart
        |> List.intersperse (Element.text " ")
        |> Element.paragraph []


urlRegex : Regex
urlRegex =
    let
        -- TODO: Use VerEx.captureGroup when PR is merged
        -- https://github.com/VerbalExpressions/elm-verbal-expressions/pull/3
        captureGroup expression =
            VerEx.beginCapture >> expression >> VerEx.endCapture
    in
    VerEx.verex
        |> VerEx.startOfLine
        |> VerEx.possibly "<"
        |> captureGroup
            (VerEx.followedBy "http"
                >> VerEx.possibly "s"
                >> VerEx.followedBy "://"
                >> VerEx.somethingBut ">"
            )
        |> VerEx.possibly ">"
        |> VerEx.possibly "."
        |> VerEx.endOfLine
        |> VerEx.withAnyCase True
        |> VerEx.toRegex


testForUrl : String -> Maybe String
testForUrl part =
    part
        |> Regex.find urlRegex
        |> List.map .submatches
        |> List.concat
        |> Maybe.values
        |> List.head


viewTopicPart : String -> Element msg
viewTopicPart part =
    case testForUrl part of
        Just url ->
            viewLink url url

        Nothing ->
            Element.text part


viewTimeZones : RemoteData Users -> Maybe Plot.Point -> WindowSize -> Element Msg
viewTimeZones remoteData hoveredBar { width } =
    case remoteData of
        Loading ->
            viewLoading "Time Zones"

        Error ->
            viewTryAgain RequestUsers

        Data users ->
            let
                size =
                    if width < 930 then
                        width - 30

                    else
                        900
            in
            Element.column
                [ Font.alignLeft
                , Element.spacing 50
                , Element.width (Element.px size)
                , Element.centerX
                ]
                [ viewTitle "Time Zones"
                , viewPlot users hoveredBar size
                ]


viewPlot : Users -> Maybe Plot.Point -> Int -> Element Msg
viewPlot users hoveredBar size =
    let
        defaultConfig =
            Plot.defaultBarsPlotCustomizations

        onHovering stuff x =
            hoveredBar
                |> Maybe.andThen (maybeWhen (.x >> (==) x) stuff)

        customTick position =
            { attributes = [ SvgAttr.stroke "rgb(187, 187, 187)" ]
            , length = 3
            , position = position
            }

        customAxisLine summary =
            Just
                (Plot.fullLine
                    [ SvgAttr.stroke "rgb(187, 187, 187)"
                    ]
                    summary
                )

        horizontalAxis =
            Plot.customAxis <|
                \summary ->
                    { position = Plot.closestToZero
                    , axisLine = customAxisLine summary
                    , ticks =
                        summary.all
                            |> List.map (\a -> (-) a summary.min)
                            |> List.map customTick
                    , labels = []
                    , flipAnchor = False
                    }

        customFlyingHintContainer inner summary hints =
            Maybe.unwrap (Html.text "") (viewCustomFlyingHintContainer inner summary hints) hoveredBar

        viewCustomFlyingHintContainer inner summary hints point =
            let
                axisLength { length, marginLower, marginUpper } =
                    length - marginLower - marginUpper

                range { min, max } =
                    if max - min /= 0 then
                        max - min

                    else
                        1

                scaleValue axis value =
                    value * axisLength axis / range axis

                toSVGX value =
                    scaleValue summary.x (value - summary.x.min) + summary.x.marginLower

                xOffset =
                    toSVGX point.x * 100 / summary.x.length

                isLeft =
                    (point.x - summary.x.min) < range summary.x / 4

                isRight =
                    (point.x - summary.x.min) > range summary.x * 3 / 4

                verticalPosition =
                    let
                        top =
                            List.getAt (floor point.x - 1) (List.reverse summary.y.all)
                                |> Maybe.unwrap 0 ((*) (1 / summary.y.dataMax))
                    in
                    String.fromFloat ((440 - 50) * toFloat size / 647 * (1 - top) - 50) ++ "px"
            in
            Html.div
                [ HtmlAttr.style "position" "absolute"
                , HtmlAttr.style "top" verticalPosition
                , HtmlAttr.style "right" (String.fromFloat (100 - xOffset) ++ "%")
                , HtmlAttr.style "pointer-events" "none"
                ]
                [ inner hints isLeft isRight ]

        customHintContainerInner hints isLeft isRight =
            let
                shiftAttrs =
                    if isLeft then
                        [ HtmlAttr.style "left" "100%"
                        , HtmlAttr.style "margin-left" "-22px"
                        ]

                    else if isRight then
                        [ HtmlAttr.style "right" "-22px"
                        ]

                    else
                        [ HtmlAttr.style "right" "-50%"
                        ]

                arrowShiftAttrs =
                    if isLeft then
                        [ HtmlAttr.style "left" "14px"
                        ]

                    else if isRight then
                        [ HtmlAttr.style "right" "14px"
                        ]

                    else
                        [ HtmlAttr.style "left" "50%"
                        , HtmlAttr.style "margin-left" "-6px"
                        ]

                arrow =
                    Html.div
                        (arrowShiftAttrs
                            ++ [ HtmlAttr.style "position" "absolute"
                               , HtmlAttr.style "top" "100%"
                               , HtmlAttr.style "width" "0"
                               , HtmlAttr.style "height" "0"
                               , HtmlAttr.style "border-left" "6px solid transparent"
                               , HtmlAttr.style "border-right" "6px solid transparent"
                               , HtmlAttr.style "border-top" "6px solid rgb(52, 73, 94)"
                               ]
                        )
                        []
            in
            Html.div
                (shiftAttrs
                    ++ [ HtmlAttr.style "line-height" "40px"
                       , HtmlAttr.style "color" "white"
                       , HtmlAttr.style "padding" "0 10px"
                       , HtmlAttr.style "position" "relative"
                       , HtmlAttr.style "background" "rgb(52, 73, 94)"
                       , HtmlAttr.style "border-radius" "6px"
                       , HtmlAttr.style "border" "2px solid #fff"
                       ]
                )
                (arrow :: hints)

        config =
            { defaultConfig
                | attributes = [ HtmlAttr.style "width" (String.fromInt size ++ "px") ]
                , width = 647
                , height = 440
                , margin = { top = 0, bottom = 50, right = 25, left = 25 }
                , horizontalAxis = horizontalAxis
                , onHover = Just BarHovered
                , hintContainer = customFlyingHintContainer customHintContainerInner
            }

        verticalAxis =
            Plot.customAxis <|
                \summary ->
                    { position = Plot.closestToZero
                    , axisLine = customAxisLine summary
                    , ticks = List.map customTick (Plot.decentPositions summary)
                    , labels = []
                    , flipAnchor = False
                    }

        customLabel label position =
            { view =
                Plot.viewLabel
                    [ SvgAttr.transform "rotate(-60) translate(-3 -3)"
                    , SvgAttr.fontSize "8"
                    , SvgAttr.fill "rgb(187, 187, 187)"
                    ]
                    label
            , position = position
            }

        toGroup { number, timeZone } =
            { label = customLabel (toUtc timeZone)
            , hint =
                onHovering
                    (Html.span []
                        [ Html.text (toUtc timeZone ++ ": ")
                        , Html.span
                            [ HtmlAttr.style "font-weight" "bold" ]
                            [ Html.text (String.fromFloat number) ]
                        ]
                    )
            , verticalLine = always Nothing
            , bars =
                [ { label = Nothing
                  , height = number
                  }
                ]
            }

        customBars =
            { axis = verticalAxis
            , toGroups = List.map toGroup
            , styles =
                [ [ SvgAttr.fill "rgba(96, 181, 204, 0.75)"
                  , SvgAttr.stroke "rgb(96, 181, 204)"
                  , SvgAttr.strokeWidth "1"
                  ]
                ]
            , maxWidth = Plot.Percentage 80
            }
    in
    users.timeZones
        |> Plot.viewBarsCustom config customBars
        |> Element.html
        |> Element.el []


toUtc : Float -> String
toUtc offset =
    let
        symbol =
            if offset > 0 then
                "+"

            else if offset == 0 then
                "±"

            else
                "-"

        first =
            if floor (abs offset) < 10 then
                "0" ++ String.fromInt (floor (abs offset))

            else
                String.fromInt (floor (abs offset))

        last =
            if (abs offset - toFloat (floor (abs offset))) > 0 then
                String.fromFloat ((abs offset - toFloat (floor (abs offset))) * 60)

            else
                "00"
    in
    "UTC " ++ symbol ++ first ++ ":" ++ last


viewFooter : Element msg
viewFooter =
    Element.paragraph []
        [ Element.text "All code for this site is open source and written in Elm. "
        , viewLink "https://github.com/akoppela/elm-lang-slack" "Check it out!"
        , Element.text " — © 2018 Andrey Koppel"
        ]



-- VIEW HELPERS


elmSlack : String
elmSlack =
    "https://elmlang.slack.com/"


viewTitle : String -> Element msg
viewTitle title =
    Element.el
        [ Region.heading 2
        , Font.size 40
        , Element.paddingEach { top = 0, bottom = 50, left = 0, right = 0 }
        , Element.centerX
        ]
        (Element.text title)


viewButton : String -> String -> Element msg
viewButton url label =
    Element.newTabLink
        [ Background.color (Element.rgb255 52 73 94)
        , Border.rounded 6
        , Element.padding 12
        ]
        { url = url
        , label =
            Element.el
                [ Font.color (Element.rgb255 255 255 255)
                ]
                (Element.text label)
        }


viewLinkLabel : List (Attribute msg) -> String -> Element msg
viewLinkLabel attrs label =
    Element.el
        (List.append
            [ Font.color (Element.rgb255 96 181 204)
            , Font.underline
            , Element.htmlAttribute (HtmlAttr.style "white-space" "normal")
            , Element.htmlAttribute (HtmlAttr.style "word-break" "break-all")
            , Element.mouseOver
                [ Font.color (Element.rgb255 234 21 122)
                ]
            ]
            attrs
        )
        (Element.text label)


viewLink : String -> String -> Element msg
viewLink url label =
    Element.newTabLink []
        { url = url
        , label = viewLinkLabel [] label
        }


viewBoldLink : String -> String -> Element msg
viewBoldLink url label =
    Element.newTabLink []
        { url = url
        , label = viewLinkLabel [ Font.bold ] label
        }


viewLinkWithMsg : msg -> String -> Element msg
viewLinkWithMsg msg label =
    viewLinkLabel
        [ Events.onClick msg
        , Element.pointer
        ]
        label


viewLoading : String -> Element msg
viewLoading text =
    Element.el [ Element.centerX ] <|
        Element.text ("Loading " ++ text ++ " ...")


viewTryAgain : msg -> Element msg
viewTryAgain msg =
    Element.paragraph []
        [ Element.text "There was an error. Please "
        , viewLinkWithMsg msg "try again"
        , Element.text "."
        ]



-- HELPERS


{-| Takes some value and maybe test.
Returns just value if test is just true.
Otherwise returns nothing.
-}
maybeWhen : (a -> Bool) -> b -> a -> Maybe b
maybeWhen test returnValue givenValue =
    if test givenValue then
        Just returnValue

    else
        Nothing
