module Main exposing (main)

import Color
import Element as E exposing (Attribute, Element)
import Element.Area as Area
import Element.Background as Background
import Element.Border as Border
import Element.Events as Events
import Element.Font as Font
import ElmLogo
import Html as H exposing (Html)
import Html.Attributes as HtmlA
import Http
import Json.Decode as Decode exposing (Decoder)
import List.Extra as List
import Maybe.Extra as Maybe
import Plot
import Regex exposing (Regex)
import Svg.Attributes as SvgA
import VerbalExpressions as VerEx
import Window


main : Program Flags Model Msg
main =
    H.programWithFlags
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
    , windowSize : Window.Size
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
    | WindowSizeChanged Window.Size


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        RequestUsers ->
            ( { model | users = Loading }, requestUsers )

        UsersRequested (Ok users) ->
            ( { model | users = Data users }, Cmd.none )

        UsersRequested (Err _) ->
            ( { model | users = Error }, Cmd.none )

        RequestChannels ->
            ( { model | channels = Loading }, requestChannels )

        ChannelsRequested (Ok channels) ->
            ( { model | channels = Data channels }, Cmd.none )

        ChannelsRequested (Err _) ->
            ( { model | channels = Error }, Cmd.none )

        BarHovered hoveredBar ->
            ( { model | hoveredBar = hoveredBar }, Cmd.none )

        WindowSizeChanged size ->
            ( { model | windowSize = size }, Cmd.none )


requestUsers : Cmd Msg
requestUsers =
    requestFirebase "users" usersDecoder UsersRequested


requestChannels : Cmd Msg
requestChannels =
    requestFirebase "channels" channelsDecoder ChannelsRequested


requestFirebase : String -> Decoder a -> (Result Http.Error a -> msg) -> Cmd msg
requestFirebase document decoder toMsg =
    let
        url =
            "https://us-central1-elm-lang-slack.cloudfunctions.net/getData?document=" ++ document
    in
    Http.send toMsg (Http.get url decoder)



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Window.resizes WindowSizeChanged



--VIEW


view : Model -> Html Msg
view model =
    E.layout
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
        , Font.color (Color.rgb 41 60 75)
        , Font.size 24
        , Font.center
        , Background.color Color.white
        , E.paddingXY 15 100
        ]
        (E.column [ E.spacing 100 ]
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
    E.column [ E.spacing 50 ]
        [ ElmLogo.element 70
        , E.el
            [ Area.heading 1
            , Font.size 120
            , Font.lineHeight 1
            , E.centerY
            ]
            (E.text "elm")
        , E.column
            [ E.spacing 10 ]
            [ E.paragraph [] [ E.text ("We are a community of " ++ usersNumber) ]
            , E.paragraph [] [ E.text "Elm language developers from all over the world." ]
            , E.paragraph [] [ E.text "Join us and talk on Slack!" ]
            ]
        , viewButton "http://elmlang.herokuapp.com/" "Join Now"
        , viewLink elmSlack "Already a member? Sign in here."
        ]


viewChannels : RemoteData (List Channel) -> Element Msg
viewChannels remoteData =
    case remoteData of
        Loading ->
            viewLoading "Channels"

        Error ->
            viewTryAgain RequestChannels

        Data channels ->
            E.column
                [ Font.alignLeft
                , E.spacing 50
                , E.center
                , E.width E.shrink
                , E.attribute (HtmlA.style [ ( "max-width", "600px" ) ])
                ]
                (viewTitle "Channels" :: List.map viewChannel channels)


viewChannel : Channel -> Element msg
viewChannel channel =
    E.column [ E.spacing 10 ]
        [ E.paragraph [] [ viewBoldLink (elmSlack ++ "messages/" ++ channel.id) ("#" ++ channel.name) ]
        , viewTopic channel.topic
        , E.paragraph []
            [ E.el [ Font.color (Color.rgb 96 181 204), Font.bold ] (E.text (toString channel.members))
            , E.text " "
            , E.el [ Font.color (Color.rgb 187 187 187) ] (E.text "members")
            ]
        ]


viewTopic : String -> Element msg
viewTopic topic =
    topic
        |> Regex.split Regex.All (Regex.regex "\\s")
        |> List.map viewTopicPart
        |> List.intersperse (E.text " ")
        |> E.paragraph []


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
        |> VerEx.endOfLine
        |> VerEx.withAnyCase True
        |> VerEx.toRegex


testForUrl : String -> Maybe String
testForUrl part =
    part
        |> Regex.find Regex.All urlRegex
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
            E.text part


viewTimeZones : RemoteData Users -> Maybe Plot.Point -> Window.Size -> Element Msg
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
            E.column
                [ Font.alignLeft
                , E.spacing 50
                , E.width (E.px size)
                , E.center
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
            { attributes = [ SvgA.stroke "rgb(187, 187, 187)" ]
            , length = 3
            , position = position
            }

        customAxisLine summary =
            Just
                (Plot.fullLine
                    [ SvgA.stroke "rgb(187, 187, 187)"
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
                            |> List.map (flip (-) summary.min)
                            |> List.map customTick
                    , labels = []
                    , flipAnchor = False
                    }

        customFlyingHintContainer inner summary hints =
            Maybe.unwrap (H.text "") (viewCustomFlyingHintContainer inner summary hints) hoveredBar

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
                    ( "top", toString ((440 - 50) * toFloat size / 647 * (1 - top) - 50) ++ "px" )

                style =
                    [ ( "position", "absolute" )
                    , verticalPosition
                    , ( "right", toString (100 - xOffset) ++ "%" )
                    , ( "pointer-events", "none" )
                    ]
            in
            H.div [ HtmlA.style style ] [ inner hints isLeft isRight ]

        customHintContainerInner hints isLeft isRight =
            let
                shift attrs =
                    if isLeft then
                        ( "left", "100%" ) :: ( "margin-left", "-22px" ) :: attrs
                    else if isRight then
                        ( "right", "-22px" ) :: attrs
                    else
                        ( "right", "-50%" ) :: attrs

                arrowShift attrs =
                    if isLeft then
                        ( "left", "14px" ) :: attrs
                    else if isRight then
                        ( "right", "14px" ) :: attrs
                    else
                        ( "left", "50%" ) :: ( "margin-left", "-6px" ) :: attrs

                arrow =
                    H.div
                        [ HtmlA.style <|
                            arrowShift
                                [ ( "position", "absolute" )
                                , ( "top", "100%" )
                                , ( "width", "0" )
                                , ( "height", "0" )
                                , ( "border-left", "6px solid transparent" )
                                , ( "border-right", "6px solid transparent" )
                                , ( "border-top", "6px solid rgb(52, 73, 94)" )
                                ]
                        ]
                        []
            in
            H.div
                [ HtmlA.style <|
                    shift
                        [ ( "line-height", "40px" )
                        , ( "color", "white" )
                        , ( "padding", "0 10px" )
                        , ( "position", "relative" )
                        , ( "background", "rgb(52, 73, 94)" )
                        , ( "border-radius", "6px" )
                        , ( "border", "2px solid #fff" )
                        ]
                ]
                (arrow :: hints)

        config =
            { defaultConfig
                | attributes = [ HtmlA.style [ ( "width", toString size ++ "px" ) ] ]
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
                    [ SvgA.transform "rotate(-60) translate(-3 -3)"
                    , SvgA.fontSize "8"
                    , SvgA.fill "rgb(187, 187, 187)"
                    ]
                    label
            , position = position
            }

        toGroup { number, timeZone } =
            { label = customLabel (toUtc timeZone)
            , hint =
                onHovering
                    (H.span []
                        [ H.text (toUtc timeZone ++ ": ")
                        , H.span
                            [ HtmlA.style [ ( "font-weight", "bold" ) ] ]
                            [ H.text (toString number) ]
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
                [ [ SvgA.fill "rgba(96, 181, 204, 0.75)"
                  , SvgA.stroke "rgb(96, 181, 204)"
                  , SvgA.strokeWidth "1"
                  ]
                ]
            , maxWidth = Plot.Percentage 80
            }
    in
    users.timeZones
        |> Plot.viewBarsCustom config customBars
        |> E.html
        |> E.el []


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
                "0" ++ toString (floor (abs offset))
            else
                toString (floor (abs offset))

        last =
            if (abs offset - toFloat (floor (abs offset))) > 0 then
                toString ((abs offset - toFloat (floor (abs offset))) * 60)
            else
                "00"
    in
    "UTC " ++ symbol ++ first ++ ":" ++ last


viewFooter : Element msg
viewFooter =
    E.paragraph []
        [ E.text "All code for this site is open source and written in Elm. "
        , viewLink "https://github.com/akoppela/elm-lang-slack" "Check it out!"
        , E.text " — © 2018 Andrey Koppel"
        ]



-- VIEW HELPERS


elmSlack : String
elmSlack =
    "https://elmlang.slack.com/"


viewTitle : String -> Element msg
viewTitle title =
    E.el
        [ Area.heading 2
        , Font.size 40
        , Font.lineHeight 1
        , E.paddingEach { top = 0, bottom = 50, left = 0, right = 0 }
        ]
        (E.text title)


viewButton : String -> String -> Element msg
viewButton url label =
    E.newTabLink
        [ Background.color (Color.rgb 52 73 94)
        , Border.rounded 6
        , E.padding 12
        ]
        { url = url
        , label = E.el [ Font.color Color.white ] (E.text label)
        }


viewLinkLabel : List (Attribute msg) -> String -> Element msg
viewLinkLabel attrs label =
    E.el
        (List.append
            [ Font.color (Color.rgb 96 181 204)
            , Font.mouseOverColor (Color.rgb 234 21 122)
            , Font.underline
            , E.attribute
                (HtmlA.style
                    [ ( "white-space", "normal" )
                    , ( "word-break", "break-all" )
                    ]
                )
            ]
            attrs
        )
        (E.text label)


viewLink : String -> String -> Element msg
viewLink url label =
    E.newTabLink []
        { url = url
        , label = viewLinkLabel [] label
        }


viewBoldLink : String -> String -> Element msg
viewBoldLink url label =
    E.newTabLink []
        { url = url
        , label = viewLinkLabel [ Font.bold ] label
        }


viewLinkWithMsg : msg -> String -> Element msg
viewLinkWithMsg msg label =
    viewLinkLabel [ Events.onClick msg ] label


viewLoading : String -> Element msg
viewLoading text =
    E.text ("Loading " ++ text ++ " ...")


viewTryAgain : msg -> Element msg
viewTryAgain msg =
    E.paragraph []
        [ E.text "There was an error. Please "
        , viewLinkWithMsg msg "try again"
        , E.text "."
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
