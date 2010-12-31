module MCollective
    module Security
        # TODO:
        #    - machines receiving registration or no reply messages will keep track of IDs in @requestors
        #      but will never remove them from the hash need to do housekeeping on the hash somehow
        #    - investigate sending the public key with every request/reply this will probably require
        #      the addition of a CA to validate that certs we're receiving is trusted.  Really dont
        #      think this is a problem as you shouldnt just let random hosts connect to your middleware
        #      so we really should be able to trust that people cant just inject anything into the thing
        #      just like with TCP you need firewwalls so too do you need to use the middleware security
        #      mechanisms to restrict access to your machines
        class Encrypted_ssl<Base
            def decodemsg(msg)
                body = deserialize(msg.payload)

                # if we get a message that has a pubkey attached and we're set to learn
                # then add it to the client_cert_dir this should only happen on servers
                # since clients will get replies using their own pubkeys
                if @config.pluginconf["ssl.learn_pubkeys"]
                    if body.include?(:sslpubkey)
                        if client_cert_dir
                            certname = certname_from_callerid(body[:callerid])
                            if certname
                                certfile = "#{client_cert_dir}/#{certname}.pem"
                                unless File.exist?(certfile)
                                    @log.debug("Caching client cert in #{certfile}")
                                    File.open(certfile, "w") {|f| f.print body[:sslpubkey]}
                                end
                            end
                        end
                    end
                end

                cryptdata = {:key => body[:sslkey], :data => body[:body]}

                if @initiated_by == :client
                    body[:body] = deserialize(decrypt(cryptdata, nil))
                else
                    body[:body] = deserialize(decrypt(cryptdata, body[:callerid]))
                end

                return body
            end

            # Encodes a reply
            def encodereply(sender, target, msg, requestid, requestcallerid)
                crypted = encrypt(serialize(msg), requestcallerid)

                @log.debug("Encoded a reply for request #{requestid} for #{requestcallerid}")

                req = {:senderid => @config.identity,
                       :requestid => requestid,
                       :senderagent => sender,
                       :msgtarget => target,
                       :msgtime => Time.now.to_i,
                       :sslkey => crypted[:key],
                       :body => crypted[:data]}

                serialize(req)
            end

            # Encodes a request msg
            def encoderequest(sender, target, msg, requestid, filter={})
                crypted = encrypt(serialize(msg), callerid)

                @log.debug("Encoding a request for '#{target}' with request id #{requestid}")

                req = {:senderid => @config.identity,
                       :requestid => requestid,
                       :msgtarget => target,
                       :msgtime => Time.now.to_i,
                       :body => crypted,
                       :filter => filter,
                       :callerid => callerid,
                       :sslkey => crypted[:key],
                       :body => crypted[:data]}

                if @config.pluginconf["ssl.send_pubkey"]
                    if @initiated_by == :client
                        req[:sslpubkey] = File.read(client_public_key)
                    else
                        req[:sslpubkey] = File.read(server_public_key)
                    end
                end

                serialize(req)
            end

            # Serializes a message using the configured encoder
            def serialize(msg)
                serializer = @config.pluginconf["ssl.serializer"] || "marshal"

                @log.debug("Serializing using #{serializer}")

                case serializer
                    when "yaml"
                        return YAML.dump(msg)
                    else
                        return Marshal.dump(msg)
                end
            end

            # De-Serializes a message using the configured encoder
            def deserialize(msg)
                serializer = @config.pluginconf["ssl.serializer"] || "marshal"

                @log.debug("De-Serializing using #{serializer}")

                case serializer
                    when "yaml"
                        return YAML.load(msg)
                    else
                        return Marshal.load(msg)
                end
            end

            # sets the caller id to the md5 of the public key
            def callerid
                if @initiated_by == :client
                    return "cert=#{File.basename(client_public_key).gsub(/\.pem$/, '')}"
                else
                    # servers need to set callerid as well, not usually needed but
                    # would be if you're doing registration or auditing or generating
                    # requests for some or other reason
                    "cert=#{File.basename(server_public_key).gsub(/\.pem$/, '')}"
                end
            end

            def encrypt(string, certid)
                if @initiated_by == :client
                    @ssl ||= SSL.new(client_public_key, client_private_key)

                    @log.debug("Encrypting message using private key")
                    return @ssl.encrypt_with_private(string)
                else
                    # when the server is initating requests like for registration
                    # then the certid will be our callerid
                    if certid == callerid
                        @log.debug("Encrypting message using private key #{server_private_key}")

                        ssl = SSL.new(server_public_key, server_private_key)
                        return ssl.encrypt_with_private(string)
                    else
                        @log.debug("Encrypting message using public key for #{certid}")

                        ssl = SSL.new(public_key_path_for_client(certid))
                        return ssl.encrypt_with_public(string)
                    end
                end
            end

            def decrypt(string, certid)
                if @initiated_by == :client
                    @ssl ||= SSL.new(client_public_key, client_private_key)

                    @log.debug("Decrypting message using private key")
                    return @ssl.decrypt_with_private(string)
                else
                    @log.debug("Decrypting message using public key for #{certid}")

                    ssl = SSL.new(public_key_path_for_client(certid))
                    return ssl.decrypt_with_public(string)
                end
            end

            # On servers this will look in the ssl.client_cert_dir for public
            # keys matching the clientid, clientid is expected to be in the format
            # set by callerid
            def public_key_path_for_client(clientid)
                raise "Unknown callerid format in '#{clientid}'" unless clientid.match(/^cert=(.+)$/)

                clientid = $1

                client_cert_dir + "/#{clientid}.pem"
            end

            # Figures out the client private key either from MCOLLECTIVE_SSL_PRIVATE or the
            # plugin.ssl.client_private config option
            def client_private_key
                return ENV["MCOLLECTIVE_SSL_PRIVATE"] if ENV.include?("MCOLLECTIVE_SSL_PRIVATE")

                raise("No plugin.ssl.client_private configuration option specified") unless @config.pluginconf.include?("ssl.client_private")

                return @config.pluginconf["ssl.client_private"]
            end

            # Figures out the client public key either from MCOLLECTIVE_SSL_PUBLIC or the
            # plugin.ssl.client_public config option
            def client_public_key
                return ENV["MCOLLECTIVE_SSL_PUBLIC"] if ENV.include?("MCOLLECTIVE_SSL_PUBLIC")

                raise("No plugin.ssl.client_public configuration option specified") unless @config.pluginconf.include?("ssl.client_public")

                return @config.pluginconf["ssl.client_public"]
            end

            # Figures out the server public key from the plugin.ssl.server_public config option
            def server_public_key
                raise("No ssl.server_public configuration option specified") unless @config.pluginconf.include?("ssl.server_public")
                return @config.pluginconf["ssl.server_public"]
            end

            # Figures out the server private key from the plugin.ssl.server_private config option
            def server_private_key
                raise("No plugin.ssl.server_private configuration option specified") unless @config.pluginconf.include?("ssl.server_private")
                @config.pluginconf["ssl.server_private"]
            end

            # Figures out where to get client public certs from the plugin.ssl.client_cert_dir config option
            def client_cert_dir
                raise("No plugin.ssl.client_cert_dir configuration option specified") unless @config.pluginconf.include?("ssl.client_cert_dir")
                @config.pluginconf["ssl.client_cert_dir"]
            end

            # Takes our cert=foo callerids and return the foo bit else nil
            def certname_from_callerid(id)
                if id =~ /^cert=(.+)/
                    return $1
                else
                    return nil
                end
            end
        end
    end
end
