module MCollective
    module Security
        class Encrypted_ssl<Base
            def decodemsg(msg)
                body = deserialize(msg.payload)
                cryptdata = {:key => body[:sslkey], :data => body[:body]}

                if @initiated_by == :client
                    body[:body] = deserialize(decrypt(cryptdata, nil))
                else
                    body[:body] = deserialize(decrypt(cryptdata, body[:callerid]))

                    @requestors ||= {}

                    # record who requested a message
                    Thread.exclusive { @requestors[body[:requestid]] = body[:callerid] }
                end

                return body
            end

            # Encodes a reply
            def encodereply(sender, target, msg, requestid, filter={})
                unless @requestors.include?(requestid)
                    @log.error("Could not reply, we do not know who made request #{requestid}")
                    raise "Could not encode reply, unknown requestor for request #{request}"
                end

                crypted = encrypt(serialize(msg), @requestors[requestid])

                Thread.exclusive { @requestors.delete(requestid) }

                @log.debug("Encoded a message for request #{requestid}")

                serialize({:senderid => @config.identity,
                           :requestid => requestid,
                           :senderagent => sender,
                           :msgtarget => target,
                           :msgtime => Time.now.to_i,
                           :sslkey => crypted[:key],
                           :body => crypted[:data]})
            end

            # Encodes a request msg
            #
            # TODO: registration is initiated by the servers who dont have
            #       the usual layout, we would need to put all servers
            #       public keys at the location where registration messages
            #       get consumed for this to work.  So think about that later
            #       for now registration just isnt supported
            #
            def encoderequest(sender, target, msg, requestid, filter={})
                if @initiated_by == :client
                    crypted = encrypt(serialize(msg), callerid)
                else
                    raise "Servers making requests is not yet supported in this version of the security plugin"
                end


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

                req[:callerid] = callerid if  @initiated_by == :client

                serialize(req)
            end

            # Serializes a message using the configured encoder
            def serialize(msg)
                serializer = @config.pluginconf["ssl_serializer"] || "marshal"

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
                serializer = @config.pluginconf["ssl_serializer"] || "marshal"

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
                    return ""
                end
            end

            def encrypt(string, certid)
                if @initiated_by == :client
                    @ssl ||= SSL.new(client_public_key, client_private_key)

                    @log.debug("Encrypting message using private key")
                    return @ssl.encrypt_with_private(string)
                else
                    @log.debug("Encrypting message using public key for #{certid}")

                    ssl = SSL.new(public_key_path_for_client(certid))
                    return ssl.encrypt_with_public(string)
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

            # On servers this will look in the ssl_client_cert_dir for public
            # keys matching the clientid, clientid is expected to be in the format
            # set by callerid
            def public_key_path_for_client(clientid)
                raise "Unknown callerid format in '#{clientid}'" unless clientid.match(/^cert=(.+)$/)

                clientid = $1

                client_cert_dir + "/#{clientid}.pem"
            end

            # Figures out the client private key either from MCOLLECTIVE_SSL_PRIVATE or the
            # plugin.ssl_client_private config option
            def client_private_key
                return ENV["MCOLLECTIVE_SSL_PRIVATE"] if ENV.include?("MCOLLECTIVE_SSL_PRIVATE")

                raise("No plugin.ssl_client_private configuration option specified") unless @config.pluginconf.include?("ssl_client_private")

                return @config.pluginconf["ssl_client_private"]
            end

            # Figures out the client public key either from MCOLLECTIVE_SSL_PUBLIC or the
            # plugin.ssl_client_public config option
            def client_public_key
                return ENV["MCOLLECTIVE_SSL_PUBLIC"] if ENV.include?("MCOLLECTIVE_SSL_PUBLIC")

                raise("No plugin.ssl_client_public configuration option specified") unless @config.pluginconf.include?("ssl_client_public")

                return @config.pluginconf["ssl_client_public"]
            end

            # Figures out where to get client public certs from the plugin.ssl_client_cert_dir config option
            def client_cert_dir
                raise("No plugin.ssl_client_cert_dir configuration option specified") unless @config.pluginconf.include?("ssl_client_cert_dir")
                @config.pluginconf["ssl_client_cert_dir"]
            end
        end
    end
end
