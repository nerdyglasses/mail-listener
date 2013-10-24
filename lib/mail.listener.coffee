util             = require "util"
{EventEmitter}   = require "events"
# {MailParser}     = require "mailparser"
{ImapConnection} = require "imap"

# MailListener class. Can `emit` events in `node.js` fashion.
class MailListener extends EventEmitter

  constructor: (@account, @settings) ->
    throw new Error('MailListener: settings.mailbox not specified.') unless typeof @settings.mailbox == 'string'
    throw new Error('MailListener: settings.startDate not specified.') unless typeof @settings.startDate == 'object'
    
    @imap = new ImapConnection @account
  # start listener
  start: => 
    # 1. connect to imap server  
    @imap.connect (err) =>
      if err
        util.log "error connecting to mail server #{err}"
        @emit "error", err
      else
        # util.log "successfully connected to mail server"
        @emit "server:connected"
        # set some error event listeners
        @imap.on 'close', (err) =>
          # console.log 'close', util.inspect(err)
          @emit 'server:close', err
        @imap.on 'error', (err) =>
          # console.log 'error', util.inspect(err)
          @emit 'server:error', err
        # 2. open mailbox
        # util.log "open mailbox #{@settings.mailbox}"
        @imap.openBox @settings.mailbox, false, (err) =>
          if err
            util.log "error opening mail box #{err}"
            @emit "error", err
          else
            @emit "mailbox:connected"
            # util.log "successfully opened mail box"
            # 3a. listen for mail changes
            @imap.on 'msgupdate', (msg) =>
              # util.log "changed msg: ", util.inspect(msg)
              @emit 'mail:msgupdate', msg
            # 3b. listen for new emails in the inbox
            @searchHeaders()
            @imap.on "mail", (message_count) =>
              # util.log "#{message_count} new mail/s arrived"
              @emit "mail:arrived", message_count
              # 4. Search Emails
              @searchHeaders()
  searchHeaders: =>
    date = @settings.startDate
    date.setDate(date.getDate() - 1)
    # console.log date
    # console.log "Searching #{@account.email} since: #{date}"
    # console.log "canflags: ", @imap.permFlags
    @imap.search [ 'ALL', ['SINCE', date] ], (err, searchResults) =>
      # console.log "searchResults: ", searchResults
      if err
        util.log "error searching emails #{err}"
        @emit "error", err
      else
        try
          # 5. fetch emails
          self = @
          if searchResults.length > 0
            @imap.fetch searchResults,
              headers: true
              body: false
              cb: (fetch) ->
                # 6. email header was fetched.
                fetch.on "message", (msg) =>
                  msg.on "end", => self.emit "mail:headers", msg.uid, msg.flags
        catch error
          util.log "Error fetching Emails from Account: #{error}"
  
  fetchEmail: (id, callback) ->
    # console.log "fetching email with id: #{id}"
    @imap.fetch id,
      headers: parsed: false
      body: true
      cb: (fetch) ->
        # 6. email was fetched. Parse it!
        fetch.on "message", (msg) =>
          raw = ""
          msg.on "data", (data) ->
            # util.log('got data')
            raw += data.toString()
          msg.on "end", =>
            callback
              raw: raw
              msg: msg



  # stop listener
  stop: =>
    @imap.logout =>
      @emit "server:disconnected"

module.exports = MailListener
