module Plexus
  # Errors
  # TODO FIXME: must review all raise lines and streamline things
  
  # Base error class for the library.
  class PlexusError < StandardError; end
  
  class NoArcError < PlexusError; end
end
