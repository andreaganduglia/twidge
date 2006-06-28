{- hpodder component
Copyright (C) 2006 John Goerzen <jgoerzen@complete.org>

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
-}

module Commands.Update(cmd, cmd_worker) where
import Utils
import MissingH.Logging.Logger
import DB
import Download
import FeedParser
import Types
import Text.Printf
import Config
import Database.HDBC
import Control.Monad
import Utils

i = infoM "update"
w = warningM "update"

cmd = simpleCmd "update" 
      "Re-scan all feeds and update list of needed downloads" helptext 
      [] cmd_worker

cmd_worker gi ([], casts) =
    do podcastlist <- getSelectedPodcasts (gdbh gi) casts
       i $ printf "%d podcast(s) to consider\n" (length podcastlist)
       mapM_ (updateThePodcast gi) podcastlist

cmd_worker _ _ =
    fail $ "Invalid arguments to update; please see hpodder update --help"

updateThePodcast gi pc =
    do i $ printf " * Podcast %d: %s" (castid pc) (feedurl pc)
       feed <- bracketFeedCWD (getFeed pc)
       case feed of
         Nothing -> return ()
         Just f -> do newpc <- updateFeed gi pc f
                      updatePodcast (gdbh gi) newpc
                      i $ "   Podcast Title: " ++ (castname newpc)
       commit (gdbh gi)

updateFeed gi pcorig f =
    do count <- foldM (updateEnc gi pc) 0 (items f)
       i $ printf "   %d new episodes" count
       return pc
    where pc = pcorig {castname = sanitize_basic (channeltitle f)}

updateEnc gi pc count item = 
    do newc <- addEpisode (gdbh gi) (item2ep pc item)
       return $ count + newc

getFeed pc =
    do result <- getURL (feedurl pc) "feed.xml"
       case result of
         Success -> 
             do feed <- parse "feed.xml" (feedurl pc)
                return $ Just (feed {items = reverse (items feed)})
         _ -> do w "   Failure downloading feed"
                 return Nothing

helptext = "Usage: hpodder update [castid [castid...]]\n\n" ++ genericIdHelp ++
 "\nRunning update will cause hpodder to look at each requested podcast.  It\n\
 \will download the feed for each one and update its database of available\n\
 \episodes.  It will not actually download any episodes; see the download\n\
 \command for that."