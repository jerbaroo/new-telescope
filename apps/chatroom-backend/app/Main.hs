{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeApplications  #-}

module Main where

import           ChatRoom.Common    ( Message(..) )
import           Telescope          ( primaryKey )
import qualified Telescope         as T
import qualified Telescope.Server  as Server
import           Telescope.DS.File  ( runT )

main :: IO ()
main = do
  let msg = Message 1 "main" "john" "Hello everyone"
  _ <- runT $ T.rmTable @Message >> T.set msg
  print =<< runT (T.viewK @Message $ primaryKey msg)
  Server.run 3002 Server.developmentCors
