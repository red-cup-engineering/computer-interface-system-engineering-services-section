;;;; Groundhog Operating System (GOS)

(local util (require :util))

(local gos
       {:acts (require :acts.index)
        :conf (require :conf)
        :mem {:moments {}
              :things {}}
        :sys {:proc {:event {}
                     :events {}
                     :item {}
                     :items {}
                     :location {}
                     :mem {}
                     :moments {}
                     :sources {}
                     :things {:plants {}}
                     :time {}
                     :triage {}}
              :util (require :util)}})

(fn gos.sys.proc.event.make [details]
  (local event details)
  (when (not event.time) (set event.time (os.time)))
  (if (gos.proc.event.validate event)
      event
      (gos.sys.log
       :error (.. "Failed to make event@" event.time
                  "; didn't pass validation."))))

(fn gos.sys.proc.event.process [event]
  (if (gos.sys.proc.event.validate event)
      (do
        (local act-name event.act)
        (local act (. gos.acts act-name))
        (if act
            (do
              (local act-processor (. act :process))
              (if act-processor
                  (do
                    (gos.sys.proc.mem.setup-key :moments event.time [])
                    (table.insert (. gos.mem.moments event.time) event)
                    (act-processor gos event))
                  (do
                    (gos.sys.log
                     :error (.. "No processor function for act "
                                act-name " in event@" event.time
                                "; failed to process."))
                    (gos.sys.util.add-if-missing gos.mem.meta.acts-missing-processors
                                                 act-name))))
            (do
              (gos.sys.log
               :error (.. "No act " act-name " registered in the system"
                          "; was in an event@" event.time :.))
              (gos.sys.util.add-if-missing gos.mem.meta.unknown-acts act-name))))
      (gos.sys.log :error "Tried to process an invalid event.")))

(fn gos.sys.proc.event.save [event]
  (if (gos.sys.proc.event.validate event)
      (do
        (local time event.time)
        (if (. gos.mem.moments time)
            (table.insert (. gos.mem.moments time) event)
            (tset gos.mem.moments time [event])))
      (gos.sys.log
       :error (.. "Failed to save event@" event.time
                  "; didn't pass validation."))))
                   

(fn gos.sys.proc.event.validate-keys [event]
  (local event-keys (gos.sys.util.collect-keys event))
  (local required-keys (. (. gos.acts event.act) :required-keys))
  (local missing-keys [])
  (each [_ key (pairs required-keys)]
    (when (not (gos.sys.util.find-element event-keys key))
      (table.insert missing-keys key)))
  (if (> (length missing-keys) 0)
      (gos.sys.log
       :warning
       (.. "Failed to validate keys in event@" event.time
           "; missing required key"
           (if (> (length missing-keys) 1) :s "")
           ": " (gos.sys.util.quibble-strings missing-keys)))
      true))

(fn gos.sys.proc.event.validate [event ?triage]
  (local level (if ?triage :debug :warning))
  (fn log [msg]
    (gos.sys.log
     level (.. "Failed to validate event@" (or event.time :Unknown)
               "; " msg ".")))
  (if event.act
      (if event.time
          (if (. gos.acts event.act)
              (if (gos.sys.proc.event.validate-keys event)
                  (do
                    (when (gos.sys.util.find-item event :items)
                      (if (gos.sys.proc.items.validate event.items)
                          true
                          (log "invalid items")))
                    true)
                  (log "invalid event keys"))
              (log (.. "unknown act '" event.act "'")))
          (log "missing time"))
      (log "no act")))

(fn gos.sys.proc.events.filter-by-key [key filter ?events]
  "Filter ?EVENTS by KEY and FILTER. Without ?EVENTS, collects them from system memory."
  (gos.sys.util.filter-items-by-key
   (or ?events (gos.sys.proc.moments-collect-events))
   key filter))

(fn gos.sys.proc.item.parse [item]
  {:name (. item 1) :amount (. item 2) :unit (. item 3)})

(fn gos.sys.proc.item.validate [item]
  (if (and (= (type (. item 1)) :string)
           (= (type (. item 2)) :number)
           (= (type (. item 3)) :string))
      true
      (gos.sys.log
       :warning (.. "The following item is invalid: "
                    (gos.sys.util.fennel.view item)))))

(fn gos.sys.proc.items.validate [items]
  (local invalids [])
  (each [_ item (pairs items)]
    (when (not (gos.sys.proc.item.validate item))
      (table.insert invalids item)))
  (if (> (length invalids) 0)
      (gos.sys.log
       :warning (.. "There were invalid items found."))
      true))

(fn gos.sys.proc.location.suggest-plants [location ?season ?plants]
  (local season (or ?season (gos.sys.proc.time.reckon-season)))
  (local location-light (if location.light
                             (if (= (type location.light) :string)
                                 location.light
                                 (. location.light season))))
  (local plants (or ?plants (gos.sys.proc.things.filter-by-type :plant)))
  (local matches {})
  (each [name plant (pairs plants)]
    (local light plant.light)
    (when (= light location-light)
      (tset matches name plant))
    (when (and (gos.sys.util.array? plant.light)
               (gos.sys.util.find-element plant.light location-light))
      (tset matches name plant)))
  matches)

(fn gos.sys.proc.mem.setup-key [tab key ?form]
  (when (not (. (. gos.mem tab) key))
    (tset (. gos.mem tab) key (or ?form []))))

(fn gos.sys.proc.moments.collect-events [?moments]
  "Return a sequence of the events held in ?MOMENTS (or gos.mem.moments)"
  (local moments (or ?moments gos.mem.moments))
  (local collection [])
  (each [_ moment (pairs moments)]
    (each [_ event (pairs moment)]
      (table.insert collection event)))
  collection)

(fn gos.sys.proc.sources.search-for-item [name ?sources]
  (local sources (or ?sources gos.mem.sources))
  (local matches [])
  (each [source-name source-data (pairs sources)]
    (each [_ source-item (pairs (. source-data :items))]
      (when (= source-item name)
        (table.insert matches source-name))))
  matches)

(fn gos.sys.proc.things.find-by-name [name ?things]
  "Searches ?THINGS for one stored under NAME. Without ?THINGS, searches system memory."
  (local things (or ?things gos.mem.things))
  (local matches [])
  (each [thing-name thing (pairs things)]
    (when (= thing-name name)
      (table.insert matches thing-name)))
  (. things (. matches 1)))

(fn gos.sys.proc.things.filter-by-key [key filter ?things]
  (gos.sys.util.filter-items-by-key
   (or ?things gos.mem.things)
   key filter))

(set gos.sys.proc.things.filter-by-type
     (partial gos.sys.proc.things.filter-by-key :type))

(fn gos.sys.proc.things.collect-values [key ?things]
  (gos.sys.util.collect-values-from-items
   (or ?things gos.mem.things) key))

(set gos.sys.proc.things.collect-names
     (partial gos.sys.proc.things.collect-values :name))

(fn gos.sys.proc.things.plants.filter-by-light [light ?plants]
  (gos.sys.proc.things.filter-by-key
   :light light
   (or ?plants (gos.sys.proc.things.filter-by-type :plant))))

(fn gos.sys.proc.time.reckon-season [?time]
  (local time (or ?time (os.time)))
  (local month (. (os.date "*t" time) :month))
  (local results [1 :winter 2 :winter 3 :spring
                  4 :spring 5 :spring 6 :summer
                  7 :summer 8 :summer 9 :fall
                  10 :fall 11 :fall 12 :winter])
  (. results month))

(fn gos.sys.proc.triage.validate []
  (local triage gos.mem.event-triage)
  (local failed [])
  (each [_ event (pairs triage)]
    (when (not (gos.sys.proc.event.validate event true))
      (table.insert failed event)))
  (if (= (length failed) 0)
      true
      (gos.sys.log
       :warning (.. "Failed to validate event triage"))))

(fn gos.sys.proc.triage.process []
  (if (gos.sys.proc.triage.validate)
      (each [_ event (pairs gos.mem.event-triage)]
        (gos.sys.proc.event.process event))
      (gos.sys.log :error "Failed to process triage.")))

(set gos.sys.last-log-print 0)
(set gos.sys.log-levels {:critical 1 :error 2
                     :warning 3 :info 4
                     :debug 5 :spam 6})
(fn gos.sys.log [level message]
  "Pass on MESSAGE at LEVEL to the GOS' logging system.. Log entries get put into their log file, and also printed to the terminal if the log level is high enough."
  (local time (os.time)) (local log-spot (. (. gos.mem.logs level) time))
  (fn print-msg []
    (when (not (= gos.sys.last-log-print time))
      (set gos.sys.last-log-print time)
      (print (util.render-time time)))
    (print (.. level
               (if (= level :error) ":    "
                   (if (= level :warning) ":  "
                       (if (= level :info) ":     "
                           (if (= level :debug) ":    "
                               (if (= level :spam) ":     "
                                   ": ")))))
               message)))
  (if log-spot
      (table.insert log-spot message)
      (tset (. gos.mem.logs level) time [message]))
  (when (>= (. gos.sys.log-levels gos.conf.log-level)
            (. gos.sys.log-levels level))
    (print-msg)))

(fn gos.sys.start []
  (print "Loading GOS logs")
  (tset gos.mem :logs (gos.sys.util.load-files gos.conf.data-dirs.logs))
  (gos.sys.log :info "Starting the Groundhog Operating System")
  ;; first load data files, representing historic info
  (each [name location (pairs gos.conf.data-files)]
    (when (not (= name :moments))
      (gos.sys.log :debug (.. "Loading " name :.))
      (tset gos.mem name (gos.sys.util.load-data location))
      (gos.sys.log :debug (.. "Loaded "
                             (length (gos.sys.util.collect-keys
                                      (. gos.mem name)))
                             " " name :.))))
  (each [name location (pairs gos.conf.data-dirs)]
    (when (not (= name :logs))
      (gos.sys.log :debug (.. "Loading " name :.))
      (tset gos.mem name (gos.sys.util.load-files location))
      (gos.sys.log :debug (.. "Loaded "
                              (length (gos.sys.util.collect-keys
                                       (. gos.mem name)))
                              " " name :.))))
  ;; then load the moments file, then process its events
  (gos.sys.log :debug "Loading moments.")
  (local moments (gos.sys.util.load-data (. gos.conf.data-files :moments)))
  (gos.sys.log
   :debug (.. "Loaded " (length (gos.sys.util.collect-keys
                                 (gos.sys.proc.moments.collect-events moments)))
              " events from " (length (gos.sys.util.collect-keys moments))
              " moments; processing them."))
  (each [_ moment (pairs moments)]
    (each [_ event (pairs moment)]
      (gos.sys.proc.event.process event)))
  (gos.sys.proc.triage.validate)
  (gos.sys.log :info "GOS started.")
  (let [t (length gos.mem.event-triage)]
    (when (> t 0)
      (gos.sys.log :info (.. "There are " t " events in the triage.")))))

(fn gos.sys.save [?name]
  (if ?name
      (do
        (if (gos.sys.util.find-element
             (gos.sys.util.collect-keys gos.conf.data-files) ?name)
            (gos.sys.util.save-data
             (. gos.mem ?name) (. gos.conf.data-files ?name))
            (if (gos.sys.util.find-element
                 (gos.sys.util.collect-keys gos.conf.data-dirs) ?name)
                (each [item data (pairs (. gos.mem ?name))]
                  (gos.sys.util.save-data
                   data (.. (. gos.conf.data-dirs ?name) "/" item)))
                (gos.sys.log
                 :warning (.. "Couldn't save " ?name ", not a data-file or -dir.")))))
      (do
        (each [name location (pairs gos.conf.data-files)]
          (gos.sys.util.save-data (. gos.mem name) location))
        (each [name location (pairs gos.conf.data-dirs)]
          (each [item data (pairs (. gos.mem name))]
            (gos.sys.util.save-data data (.. location "/" name)))))))

(fn gos.triage [event]
  (when (not event.time) (set event.time (os.time)))
  (table.insert gos.mem.event-triage event)
  (gos.sys.save :event-triage))

gos
