{-# OPTIONS_GHC -fno-warn-missing-fields #-}

{-# LANGUAGE FlexibleContexts    #-}
{-# LANGUAGE MonoLocalBinds      #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE RecursiveDo         #-}
{-# LANGUAGE RecordWildCards     #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications    #-}

import           Data.Text                ( pack )
import           Control.Lens             ( view )
import           ToDoList.Common          ( ToDoList(..) )
import           Reflex.Dom
import qualified Telescope.Ops           as T
import           Telescope.DS.Reflex.Dom  ()

-- | Widget's to test different server endpoints.
main :: IO ()
main = mainWidget $ el "div" $ do
  nameDyn   <- view textInput_value <$> textInput (def &
    textInputConfig_attributes .~ (pure $ "placeholder" =: "List name"))
  toDoListDyn <- T.viewRx $ (\name -> ToDoList{..}) <$> nameDyn
  dynText $ pack . (" " ++) . show <$> toDoListDyn
