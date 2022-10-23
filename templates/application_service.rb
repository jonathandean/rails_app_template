class ApplicationService

  private

  # Set up a tagged logger for each subclass of ApplicationService.
  #
  # Log messages are prefixed with the class name.
  def logger
    @logger ||= Rails.logger.tagged(self.class.name)
  end

end