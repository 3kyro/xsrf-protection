module Http.XSRF exposing
    ( token
    , get
    , post
    , request
    , put
    )

{-| This package helps you make [XSRF](https://en.wikipedia.org/wiki/Cross-site_request_forgery) protected HTTP requests.

This package was designed to be used with [servant-auth](https://hackage.haskell.org/package/servant-auth). However it should be compatible with any
backend that supports cookie based XSRF authentication.

You can find a complete example of an elm app and a servant-auth backend using XSRF tokens [here](https://github.com/3kyro/servant-auth-elm.git).


# Setup

In order to get the cookies that the server has set, you need to ask javascript for it. The simplest way is to get hold
off the document object and pass it through a flag to Elm as a JSON Value.

    // you would normally put this in a <script> tag inside your app's
    // index.html file
    let app = Elm.App.init(
        { node: document.getElementById("myapp")
        // Pass the document object as a flag
        , flags: document
        }
    );

In Elm , you'll need to retrieve the document JSON Value sent by javascript.

    import Json.Decode as D


    -- main parametrised to D.Value to recieve the document object
    main : Program D.Value Model Msg
    main =
        Browser.element
            { init = init
            , view = view
            , update = update
            , subscriptions = subscriptions
            }

    -- Initialize the elm runtime with the document object
    init : D.Value -> ( Model, Cmd Msg )
    init document =
        ( initModel document
        , initCmd
        )

    type alias Model =
        { document : D.Value }

    initModel : D.Value -> Model
    initModel document =
        Model document


# Requests

Now that you have all current cookies in your elm app, you should check if one of them is a valid XSRF one.

@docs token

Having a valid token, you can now make some requests

@docs get
@docs post
@docs put
@docs request

-}

import Http as Http
import Json.Decode as D


{-| Similar to [Http.request](https://package.elm-lang.org/packages/elm/http/latest/Http#request), but
you also need to provide a XSRF header name and token.

In case you don't want to provide any other header except the XSRF one, you can apply the empty list
in the headers argument

    -- saves a blog post
    putPost : D.Value -> String -> Cmd msg
    putPost document post =
        XSRF.request
            { method = "PUT"
            , headers = []
            , url = "http://localhost:4000/savePost"
            , body = Http.jsonBody <| E.string post
            , expect = Http.expectWhatever
            , xsrfHeaderName = "XSRF-CUSTOM"
            , xserfToken = XSRF.token "XSRF-COOKIE=" document
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
            , xsrfToken = XSRF.token "XSRF-TOKEN=" model.document
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


{-| Create a XSRF-protected PUT request.
-}
put :
    { url : String
    , body : Http.Body
    , expect : Http.Expect msg
    , xsrfHeaderName : String
    , xsrfToken : Maybe String
    }
    -> Cmd msg
put { url, body, expect, xsrfHeaderName, xsrfToken } =
    request
        { method = "PUT"
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


{-| Get an XSRF token from a document json object.
The first argument is name the server used to set the XSRF cookie
e.g. "XSRF-TOKEN="

    token "XSRF-TOKEN=" model.document

-}
token : String -> D.Value -> Maybe String
token name value =
    let
        -- a cookies decoder
        decodeCookie =
            D.field "cookie" D.string

        -- and decode them
        rlt =
            D.decodeValue decodeCookie value

        -- split a cookie string to individual cookies
        split str =
            String.split ";" str

        -- filter those cookies to find the xsrf one
        filtered lst =
            List.filter (String.startsWith name) lst

        -- get the head of the filtered list
        head lst =
            List.head <| filtered lst

        -- and finally trim the cookie to only the token
        trimmed a =
            Maybe.map
                (String.dropLeft (String.length name))
            <|
                head <|
                    filtered <|
                        split a
    in
    case rlt of
        Err _ ->
            Nothing

        Ok cookie ->
            trimmed cookie
