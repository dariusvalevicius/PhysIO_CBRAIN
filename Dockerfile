FROM matlabruntime/r2021b/release/update4/c0130000000000000

# Copy MATLAB application
COPY ./standalone/physio_cbrain /opt/physio_cbrain

# Ensure execute permission
RUN chmod a+x /opt/physio_cbrain

# Add wrapper directory to path
ENV PATH="${PATH}:/opt/"
