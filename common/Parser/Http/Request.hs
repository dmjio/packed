{-# OPTIONS_GHC -O2 -Wall #-}

module Parser.Http.Request
  ( Request
  , parser
  , sample
  , expected
  ) where

import Data.Primitive (Array)
import Data.Word (Word8)
import Packed.Bytes (Bytes)
import Packed.Bytes.Parser (Parser)
import Packed.Bytes.Set (ByteSet)
import GHC.Exts (fromList)
import qualified Data.Char
import qualified Packed.Bytes as B
import qualified Packed.Bytes.Parser as Parser
import qualified Packed.Bytes.Set as ByteSet

data Request = Request
  { requestMethod :: {-# UNPACK #-} !Bytes
  , requestPath :: {-# UNPACK #-} !Bytes
  , requestQuery :: {-# UNPACK #-} !Bytes
  , requestVersion :: {-# UNPACK #-} !HttpVersion
  , requestHeaders :: {-# UNPACK #-} !(Array Header)
  } deriving (Show,Eq)

data HttpVersion = HttpVersion
  { httpMajor :: {-# UNPACK #-} !Int
  , httpMinor :: {-# UNPACK #-} !Int
  } deriving (Show,Eq)

data Header = Header
  { headerName :: {-# UNPACK #-} !Bytes
  , headerValue :: {-# UNPACK #-} !Bytes
  } deriving (Show,Eq)

http11 :: HttpVersion
http11 = HttpVersion 1 1

parser :: Parser Request
parser = do
  method <- Parser.takeBytesUntilByteConsume (c2w ' ')
  (path,c) <- Parser.takeBytesUntilMemberConsume spaceQuestionSet
  query <- case c of
    63 -> Parser.takeBytesUntilByteConsume (c2w ' ')
    _ -> return B.empty
  version <- parserVersion
  Parser.endOfLine
  headers <- parserHeaders
  Parser.endOfLine
  Parser.endOfInput
  return (Request method path query version headers)
  
spaceQuestionSet :: ByteSet
spaceQuestionSet = ByteSet.fromList (map c2w ['?',' '])

headerNameSet :: ByteSet
headerNameSet = ByteSet.fromList (map c2w (['_','-'] ++ ['a'..'z'] ++ ['A'..'Z'] ++ ['0'..'9']))

parserVersion :: Parser HttpVersion
parserVersion = http11 <$ Parser.bytes (s2b "HTTP/1.1")

parserHeaders :: Parser (Array Header)
parserHeaders = Parser.replicateUntilMember newlineSet parserHeader

parserHeader :: Parser Header
parserHeader = do
  name <- Parser.takeBytesWhileMember headerNameSet
  Parser.byte (c2w ':')
  Parser.skipSpace
  value <- Parser.takeBytesUntilEndOfLineConsume
  return (Header name value)

c2w :: Char -> Word8
c2w = fromIntegral . Data.Char.ord

s2b :: String -> Bytes
s2b = B.pack . map c2w

newlineSet :: ByteSet
newlineSet = ByteSet.fromList (map c2w ['\r','\n'])

expected :: Request
expected = Request
  (s2b "GET")
  (s2b "/")
  (s2b "")
  http11
  (fromList
    [ Header (s2b "Host") (s2b "twitter.com")
    , Header (s2b "Accept") (s2b "text/html, application/xhtml+xml, application/xml; q=0.9, image/webp, */*; q=0.8")
    , Header (s2b "Accept-Encoding") (s2b "gzip,deflate,sdch")
    , Header (s2b "Accept-Language") (s2b "en-GB,en-US;q=0.8,en;q=0.6")
    , Header (s2b "Cache-Control") (s2b "max-age=0")
    , Header (s2b "Cookie") (s2b "guest_id=v1%3A139; _twitter_sess=BAh7CSIKZmxhc2hJQz-e1e1; __utma=43838368.452555194.1399611824.1; __utmb=43838368; __utmc=43838368; __utmz=1399611824.1.1.utmcsr=(direct)|utmcmd=(none)")
    , Header (s2b "User-Agent") (s2b "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/35.0.1916.86 Safari/537.36")
    ]
  )

sample :: String
sample = unlines
  [ "GET / HTTP/1.1"
  , "Host: twitter.com"
  , unwords
    [ "Accept: text/html, application/xhtml+xml, application/xml; q=0.9,"
    , "image/webp, */*; q=0.8"
    ]
  , "Accept-Encoding: gzip,deflate,sdch"
  , "Accept-Language: en-GB,en-US;q=0.8,en;q=0.6"
  , "Cache-Control: max-age=0"
  , unwords
    [ "Cookie: guest_id=v1%3A139; _twitter_sess=BAh7CSIKZmxhc2hJQz-e1e1;"
    , "__utma=43838368.452555194.1399611824.1; __utmb=43838368;"
    , "__utmc=43838368; __utmz=1399611824.1.1.utmcsr=(direct)|utmcmd=(none)"
    ]
  , unwords
    [ "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_5)"
    , "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/35.0.1916.86"
    , "Safari/537.36"
    ]
  , ""
  ]
