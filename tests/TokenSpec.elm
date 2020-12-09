module TokenSpec exposing (..)

import Expect as Expect
import Fuzz exposing (Fuzzer, int, list, string, tuple)
import Http.XSRF exposing (token)
import Json.Encode as E
import Test exposing (..)


suite : Test
suite =
    describe "token"
        [ fuzz2
            (tuple ( string, string ))
            (tuple ( string, string ))
            "correctly retrievs a token from the document object"
          <|
            \a b ->
                Expect.equal
                    (token "XSRF-NAME=" (createDocument a ( "XSRF-NAME=", "XSRF-TOKEN" ) b))
                <|
                    Just "XSRF-TOKEN"
        ]


createDocument : ( String, String ) -> ( String, String ) -> ( String, String ) -> E.Value
createDocument ( n1, t1 ) ( n2, t2 ) ( n3, t3 ) =
    let
        cookies =
            n1 ++ t1 ++ ";" ++
            n2 ++ t2 ++ ";" ++
            n3 ++ t3
    in
    E.object
        [ ( n1, E.string t1 )
        , ( "cookie", E.string cookies )
        , ( n3, E.string t3 )
        ]
