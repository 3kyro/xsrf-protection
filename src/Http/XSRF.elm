module Http.XSRF exposing
    ( token
    , get
    , post
    , request
    )

{-| This package helps you make [XSRF](https://en.wikipedia.org/wiki/Cross-site_request_forgery) protected HTTP requests.

This package was designed to be used with [servant-auth](https://hackage.haskell.org/package/servant-auth). However it should be compatible with any
backend that supports cookie based XSRF authentication.

You can find a complete example of an elm app and a servant-auth backend using XSRF tokens [here](https://github.com/3kyro/servant-auth-elm.git).


# Setup

In order to get the cookies that the server has set, you need to ask javascript for it. The simplest way is to get hold
off all cookies with the `document.cookie` property.

You can use a flag for passing cookies at page initialization:

    // you would normally put this in a <script> tag inside your app's
    // index.html file
    let app = Elm.App.init(
        { node: document.getElementById("myapp")
        // Pass all cookies to elm at initialization.
        // Useful even if you are listening to cookie changes as you'll have the right
        // value in elm even if the page reloads.
        , flags: document.cookie
        }
    );

This however will not work when the server sets the XSRF cookie after the page has loaded, when responding to
a login request for example. Unfortunately as of now (December 2020) there is no standard way to listen on cookie changes.
You'll have to make the listener yourself:

    // Inside the same <script> tag as the previous app declaration
    // An onChange listener for cookies
    function onCookieChange(callback, interval = 1000) {
        let prevCookie = document.cookie;
        setInterval(()=> {
            let cookie = document.cookie;
            if (cookie !== prevCookie) {
                callback(cookie);
            }
        }, interval);
    }

You can send the changed cookies to Elm using a port

        // Still inside the <script> tag, after the declaration of app
        // Send changed cookies to elm
        onCookieChange( cookie => app.ports.toElm.send(cookie));

The finished javascript part would look like this:

    <script>
        // An onChange listener for cookies
        function onCookieChange(callback, interval = 1000) {
            let prevCookie = document.cookie;
            setInterval(()=> {
                let cookie = document.cookie;
                if (cookie !== prevCookie) {
                    callback(cookie);
                }
            }, interval);
        }

        let app = Elm.App.init(
            { node: document.getElementById("myapp")
            // Pass all cookies to elm at initialization.
            // Useful even if you are listening to cookie changes as you'll have the right
            // value in elm even in page reloads.
            , flags: document.cookie
            }
        );

        // Send changed cookies to elm
        onCookieChange( cookie => app.ports.toElm.send(cookie));
    </script>

In Elm land, you'll need to retrieve the cookies sent by javascript. You should handle flags and
ports as per elm's [documentation](https://guide.elm-lang.org/interop/).

    -- main parametrised to String to recieve the initial cookies
    main : Program String Model Msg
    main =
        Browser.element
            { init = init
            , view = view
            , update = update
            , subscriptions = subscriptions
            }

    -- Initialize the elm runtime with the cookies loaded
    init : String -> ( Model, Cmd Msg )
    init cookies =
        -- initModel sets a value of Model containing the cookies String
        ( initModel cookies
        , initCmd
        )

    -- Listen for the cookies listener message
    port toElm : (String -> msg) -> Sub msg

    -- Subscribe to cookie changes
    subscriptions : Model -> Sub Msg
    subscriptions model =
        -- fire up CookieUpdate when you receive a mesage from javascript
        toElm CookieUpdate

    -- Update the model cookies value
    update : Msg -> Model -> ( Model, Cmd Msg )
    update msg model =
        case msg of
            -- There will be other
            -- (most probably a lot of them)
            -- messages here
            CookieUpdate str ->
                ( { model | cookies = str }
                , Cmd.none
                )


# Requests

Now that you have all current cookies in your elm app, you should check if one of them is a valid XSRF one.

@docs token

Having a valid token, you can now make some requests

@docs get
@docs post
@docs request

-}

import Http as Http


{-| Similar to [Http.request](https://package.elm-lang.org/packages/elm/http/latest/Http#request), but
you also need to provide a XSRF header name and token.

In case you don't want to provide any other header except the XSRF one, you can apply the empty list
in the headers argument

    -- saves a blog post
    putPost : String -> String -> Cmd msg
    putPost cookies post =
        XSRF.request
            { method = "PUT"
            , headers = []
            , url = "http://localhost:4000/savePost"
            , body = Http.jsonBody <| E.string post
            , expect = Http.expectWhatever
            , xsrfHeaderName = "XSRF-CUSTOM"
            , xserfToken = XSRF.token "XSRF-COOKIE=" cookies
            , timeout = Nothing
            , tracker = Nothing
            }

-}
request :
    { method : String
    , headers : List Http.Header
    , url : String
    , body : Http.Body
    , expect : Http.Expect msg
    , xsrfHeaderName : String
    , xsrfToken : Maybe String
    , timeout : Maybe Float
    , tracker : Maybe String
    }
    -> Cmd msg
request { method, headers, url, body, expect, xsrfHeaderName, xsrfToken, timeout, tracker } =
    Http.request
        { method = method
        , headers =
            header xsrfHeaderName xsrfToken
                :: headers
        , url = url
        , body = body
        , expect = expect
        , timeout = timeout
        , tracker = tracker
        }


{-| Similar to [Http.get](https://package.elm-lang.org/packages/elm/http/latest/Http#get), but
you also need to provide a XSRF header name and token.

    -- A protected request for an email address
    getEmailRequest : Model -> Cmd Msg
    getEmailRequest model =
        XSRF.get
            { url = "http://localhost:4000/email"
            , expect = Http.expectJson ReceivedEmail D.string
            , xsrfHeaderName = "X-XSRF-TOKEN"
            , xsrfToken = XSRF.token "XSRF-TOKEN=" model.cookies
            }

-}
get :
    { url : String
    , expect : Http.Expect msg
    , xsrfHeaderName : String
    , xsrfToken : Maybe String
    }
    -> Cmd msg
get { url, expect, xsrfHeaderName, xsrfToken } =
    request
        { method = "GET"
        , headers = []
        , url = url
        , body = Http.emptyBody
        , expect = expect
        , xsrfHeaderName = xsrfHeaderName
        , xsrfToken = xsrfToken
        , timeout = Nothing
        , tracker = Nothing
        }


{-| Similar to [Http.post](https://package.elm-lang.org/packages/elm/http/latest/Http#post), but
you also need to provide a XSRF header name and token.
-}
post :
    { url : String
    , body : Http.Body
    , expect : Http.Expect msg
    , xsrfHeaderName : String
    , xsrfToken : Maybe String
    }
    -> Cmd msg
post { url, body, expect, xsrfHeaderName, xsrfToken } =
    request
        { method = "POST"
        , headers = []
        , url = url
        , body = body
        , expect = expect
        , xsrfHeaderName = xsrfHeaderName
        , xsrfToken = xsrfToken
        , timeout = Nothing
        , tracker = Nothing
        }


header : String -> Maybe String -> Http.Header
header headerName cookie =
    Http.header headerName <| Maybe.withDefault "" cookie


{-| Get an XSRF token from a string containing various cookies.
The first argument is name the server used to set the XSRF cookie
e.g. "XSRF-TOKEN="

    token "XSRF-TOKEN=" model.cookies

-}
token : String -> String -> Maybe String
token name str =
    let
        cookies =
            String.split ";" str

        filtered =
            List.filter (String.startsWith name) cookies
    in
    Maybe.map (String.dropLeft 11) <| List.head filtered
