{-# OPTIONS_GHC -fno-warn-missing-fields #-}

{-# LANGUAGE FlexibleContexts    #-}
{-# LANGUAGE MonoLocalBinds      #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE RecursiveDo         #-}
{-# LANGUAGE RecordWildCards     #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications    #-}

import           Control.Lens             ( (^.), view )
import           Control.Monad            ( void, when )
import           Data.Either              ( isLeft )
import qualified Data.Map                as Map
import           Data.Proxy               ( Proxy(Proxy) )
import           Data.Text.Encoding       ( encodeUtf8 )
import           Data.Text                ( Text, pack, unpack )
import           Data.These               ( These(..) )
import           Demo.Common              ( Person(..) )
import           Reflex.Dom
import qualified Telescope.Ops           as T
import           Telescope.DS.Reflex.Dom  ()
import           Text.Read                ( readMaybe )

-- | Default Person's name for input fields.
initialName :: Text
initialName = "John"

-- | Default Person's age for input fields.
initialAge :: Int
initialAge = 21

-- | Widget's to test different server endpoints.
main :: IO ()
main = mainWidget $ el "div" $ do
  viewWidget
  viewKWidget
  viewTableWidget
  setWidget
  setTableWidget
  webSocketWidget

-- | 'T.viewRx' a Person with user-input name.
viewWidget :: MonadWidget t m => m ()
viewWidget = do
  el "h3" $ text "viewRx"
  nameDyn   <- view textInput_value <$> textInput (def &
    textInputConfig_attributes .~ (pure $ "placeholder" =: "Person's name"))
  personDyn <- T.viewRx $ (\n -> Person{name = unpack n}) <$> nameDyn
  dynText $ pack . (" " ++) . show <$> personDyn

-- | 'T.viewKRx' a Person with user-input name.
viewKWidget :: MonadWidget t m => m ()
viewKWidget = do
  el "h3" $ text "viewKRx"
  nameDyn   <- view textInput_value <$> textInput (def &
    textInputConfig_attributes .~ (pure $ "placeholder" =: "Person's name"))
  personDyn <- T.viewKRx @Person (unpack <$> nameDyn)
  dynText $ pack . (" " ++) . show <$> personDyn

-- | 'T.viewTableRx' the Person table.
-- TODO: Add switch button.
viewTableWidget :: MonadWidget t m => m ()
viewTableWidget = do
  el "h3" $ text "viewTableRx"
  clickEvn  <- button "View Table"
  peopleDyn <- T.viewTableRx =<<
    holdDyn (Proxy @Person) (const (Proxy @Person) <$> clickEvn)
  void $ dyn $ personTable <$> peopleDyn

-- | 'T.setRx' a Person.
setWidget :: MonadWidget t m => m ()
setWidget = do
  el "h3" $ text "setRx"
  -- User input, converted to a 'Dynamic t Person'.
  nameInput <- textInput $ def & textInputConfig_initialValue .~ initialName
  ageEiDyn  <- numberInput (pack $ show initialAge) parseAge
  ageDyn    <- holdDyn initialAge $ filterRight $ updated ageEiDyn
  let personDyn = do
        name <- unpack <$> nameInput ^. textInput_value
        (\age -> Person{..}) <$> ageDyn
  -- Set 'Person' on every click 'Event' (filtered to valid input).
  clickEvn <- disabledButton (isLeft <$> ageEiDyn) "Set Person"
  T.setRx =<< holdDyn Person{} (tag (current personDyn) clickEvn)
  dynText =<< (holdDyn "" $ errText <$> updated ageEiDyn)
  where errText (Left t) = " " <> t
        errText _        = ""

-- | 'T.setTableRx' a table of Person.
setTableWidget :: MonadWidget t m => m ()
setTableWidget = do
  el "h3" $ text "setTableRx"
  let minRows = 1
      countRows (This _)    n = max minRows (n - 1) -- Don't go below 'minRows'.
      countRows (That _)    n = n + 1
      countRows (These _ _) n = n -- Both buttons clicked at same time.
  -- Buttons above the input table.
  rec countPEvn <- button "+ Row"
      countNEvn <- disabledButton ((<= 1) <$> numRowsDyn) "- Row"
      setEvn    <- disabledButton (isLeft <$> peopleEiDyn) "Set Table"
      numRowsDyn <- foldDyn countRows minRows $
        alignEventWithMaybe Just countNEvn countPEvn
      -- The input table.
      inputTableDyn <- el "table" $ do
        el "tr" $ (el "td" $ text "Name") >> (el "td" $ text "Age")
        simpleList ((\a -> [(1::Int)..a]) <$> numRowsDyn) $ const $ el "tr" $ do
          nameInput <- el "td" $ textInput $ def & textInputConfig_initialValue .~ initialName
          ageEiDyn  <- el "td" $ numberInput (pack $ show initialAge) parseAge
          pure $ (\name -> fmap (\age -> (unpack name, age)))
            <$> nameInput ^. textInput_value <*> ageEiDyn
      -- Set input table on click.
      let inputEiDyn  = distributeListOverDynWith sequence =<< inputTableDyn
          peopleEiDyn = (fmap $ map $ \(name, age) -> Person{..}) <$> inputEiDyn
  peopleDyn <- holdDyn [] $ filterRight $ (updated peopleEiDyn)
  T.setTableRx =<< holdDyn [Person{}] (tag (current peopleDyn) setEvn)

webSocketWidget :: MonadWidget t m => m ()
webSocketWidget = do
  -- TODO: Move to telescope-ds-reflex-dom
  el "p" $ text "Watch database"
  rec table  <- inputElement def
      rowKey <- inputElement def
      watch  <- button "Watch"
      let newMessage = fmap ((:[]) . encodeUtf8)
            $ tag (current $ zipDynWith (<>) (value table) (value rowKey))
            $ watch
  ws <- webSocket "ws://localhost:3002/watch" $ def
    & webSocketConfig_send .~ newMessage
  pure ()

-- | A list of 'Person' to a HTML "table".
personTable :: DomBuilder t m => [Person] -> m ()
personTable people = el "table" $ do
  when (not $ null people) $ do
    el "td" $ text "Name"
    el "td" $ text "Age"
  mapM_ toTableRow people
  where toTableRow :: DomBuilder t m => Person -> m ()
        toTableRow person = el "tr" $ do
          td $ pack $ name person
          td $ pack $ show $ age person
        td :: DomBuilder t m => Text -> m ()
        td text =
          void $ el "td" $ inputElement $ def
            & inputElementConfig_initialValue .~ text
            & inputElementConfig_elementConfig . elementConfig_initialAttributes .~
              ("disabled" =: "true")

-- | A valid age parsed from text, or an error message.
parseAge :: Text -> Either Text Int
parseAge t =
  let min = 0; max = 150;
  in case readMaybe $ unpack t of
    Nothing  -> Left $ "Couldn't parse \"" <> t <> "\" as \"Int\""
    Just int ->
      case int < min || int > max of
        True  -> Left $ "Not in range [" <> (pack $ show min) <> " " <> (pack $ show max) <> "]"
        False -> Right int

-- | A number input that returns parsed input.
numberInput :: DomBuilder t m => Text -> (Text -> Either a b) -> m (Dynamic t (Either a b))
numberInput initial parse = do
  n <- inputElement $ def
    & inputElementConfig_initialValue .~ initial
    & inputElementConfig_elementConfig . elementConfig_initialAttributes .~
      ("type" =: "number")
  return $ fmap parse $ _inputElement_value n

-- | A button that may be disabled.
disabledButton :: MonadWidget t m => Dynamic t Bool -> Text -> m (Event t ())
disabledButton disabledDyn s = do
  (e, _) <- flip (elDynAttr' "button") (text s) $
    (\b -> Map.fromList $ [("type", "button")] ++ disabledAttr b)
    <$> disabledDyn
  return $ domEvent Click e
  where disabledAttr True = [("disabled", "")]
        disabledAttr _    = []

{-

To test websocket in a browser:

function newws() {
  var ws = new WebSocket("ws://localhost:3001/update");
  ws.onopen = function() { console.log("Opened"); };
  ws.onmessage = function (evt) {
     var received_msg = evt.data;
     console.log("Message received...");
     console.log(received_msg);
  };
  ws.onclose = function() {
     // websocket is closed.
     console.log("Connection closed");
  };
  return ws;
};
var ws = newws();
ws.send("(TableKey \"Person\",RowKey (KeyOne (PString \"John\")))");

-}

-- -- | A HTML "br" tag
-- br :: DomBuilder t m => Int -> m ()
-- br n = sequence_ $ replicate n (el "br" $ text "")
-- -- | An empty HTML "span" tag
-- none :: DomBuilder t m => m ()
-- none = el "span" $ text ""
