util             = require "util"
{EventEmitter}   = require "events"
{MailParser}     = require "mailparser"
{ImapConnection} = require "imap"

# MailListener class. Can `emit` events in `node.js` fashion.
class MailListener extends EventEmitter

  constructor: (options) ->
    # TODO add validation for required parameters
    @mailbox = options.mailbox
    @imap = new ImapConnection
      username: options.username
      password: options.password
      host: options.host
      port: options.port
      secure: options.secure

  # start listener
  start: => 
    # 1. connect to imap server  
    @imap.connect (err) =>
      if err
        util.log "error connecting to mail server #{err}"
        @emit "error", err
      else
        util.log "successfully connected to mail server"
        @emit "server:connected"
        # set some error event listeners
        @imap.on 'close', (err) =>
          @emit 'server:close', err
        @imap.on 'error', (err) =>
          @emit 'server:error', err
        # 2. open mailbox
        util.log "open mailbox #{@mailbox}"
        @imap.openBox @mailbox, false, (err) =>
          if err
            util.log "error opening mail box #{err}"
            @emit "error", err
          else
            @emit "mailbox:connected"
            util.log "successfully opened mail box"
            # 3a. listen for mail changes
            @imap.on 'msgupdate', (msg) =>
              console.log "changed msg: ", util.inspect(msg)
              @emit 'mail:msgupdate', msg
            # 3b. listen for new emails in the inbox
            @imap.on "mail", (id) =>
              util.log "new mail arrived with id #{id}"
              @emit "mail:arrived", id
              # 4. find all unseen emails 
              @imap.search ["UNSEEN"], (err, searchResults) =>
                if err
                  util.log "error searching unseen emails #{err}"
                  @emit "error", err
                else
                  try
                    util.log "found #{searchResults.length} emails"
                    # 5. fetch emails
                    fetch = @imap.fetch searchResults,
                      markSeen: true
                      request:
                        headers: false #['from', 'to', 'subject', 'date']
                        body: "full"
                    # 6. email was fetched. Parse it!   
                    fetch.on "message", (msg) =>
                      parser = new MailParser
                      msg.on "data", (data) -> parser.write data.toString()
                      parser.on "end", (mail) =>
                        util.log "parsed mail" + util.inspect mail, false, 5
                        @emit "mail:parsed", mail
                      msg.on "end", ->
                        util.log "message id: #{msg.uid}"
                        # util.log "fetched message: " + util.inspect(msg, false, 5)
                        parser.end()
                  catch error
                    util.log "Error fetching Emails from Account: #{error}"
                    
  # stop listener
  stop: =>
    @imap.logout =>
      @emit "server:disconnected"

module.exports = MailListener