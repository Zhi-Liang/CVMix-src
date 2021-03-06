!BOP
!\newpage
! !ROUTINE: cvmix_shear_driver

! !DESCRIPTION: A routine to test the Large, et al., implementation of shear
!  mixing. Inputs are the coefficients used in Equation (28) of the paper.
!  The diffusivity coefficient is output from a single column to allow
!  recreation of the paper's Figure 3. Note that here each "level" of the
!  column denotes a different local gradient Richardson number rather than a
!  physical ocean level. All memory is declared in the driver, and the CVMix
!  data type points to the local variables.
!\\
!\\

! !INTERFACE:

Subroutine cvmix_shear_driver(nlev)

! !USES:

  use cvmix_kinds_and_types, only : cvmix_r8,                 &
                                    cvmix_zero,               &
                                    cvmix_one,                &
                                    cvmix_data_type,          &
                                    cvmix_global_params_type
  use cvmix_shear,           only : cvmix_init_shear,         &
                                    cvmix_coeffs_shear
  use cvmix_put_get,         only : cvmix_put
  use cvmix_io,              only : cvmix_io_open,            &
                                    cvmix_output_write,       &
#ifdef _NETCDF
                                    cvmix_output_write_att,   &
#endif
                                    cvmix_io_close

  Implicit None

! !INPUT PARAMETERS:
  integer, intent(in) :: nlev      ! number of Ri points to sample

!EOP
!BOC

  ! CVMix datatypes
  type(cvmix_data_type)          :: CVmix_vars
  type(cvmix_global_params_type) :: CVmix_params

  real(cvmix_r8), dimension(:), allocatable, target :: Ri_g
  real(cvmix_r8), dimension(:), allocatable, target :: Mdiff, Tdiff

  ! array index
  integer :: kw
  ! file index
  integer :: fid

  ! Namelist variables
  ! KPP mixing parameters for column
  real(cvmix_r8) :: KPP_nu_zero, KPP_Ri_zero, KPP_exp

  ! Namelist with shear mixing parameters
  namelist/KPP_nml/KPP_nu_zero, KPP_Ri_zero, KPP_exp

  ! Ri_g should increase from 0 to 1
  allocate(Ri_g(nlev+1))
  Ri_g(1) = cvmix_zero
  do kw = 2,nlev+1
    Ri_g(kw) = Ri_g(kw-1) + cvmix_one/real(nlev,cvmix_r8)
  end do

  ! Allocate memory to store viscosity and diffusivity values
  allocate(Mdiff(nlev+1), Tdiff(nlev+1))

  ! Initialization for CVMix data types
  call cvmix_put(CVmix_params,  'max_nlev', nlev)
  call cvmix_put(CVmix_params,  'prandtl',  cvmix_one)
  call cvmix_put(CVmix_vars,    'nlev',     nlev)
  ! Point CVmix_vars values to memory allocated above
  CVmix_vars%Mdiff_iface => Mdiff
  CVmix_vars%Tdiff_iface => Tdiff
  CVmix_vars%ShearRichardson_iface => Ri_g

  ! Read / set KPP parameters
  read(*, nml=KPP_nml)
  call cvmix_init_shear(mix_scheme='KPP', KPP_nu_zero=KPP_nu_zero,            &
                        KPP_Ri_zero=KPP_Ri_zero, KPP_exp=KPP_exp)
  call cvmix_coeffs_shear(CVmix_vars)

  ! Output
  ! data will have diffusivity from both columns (needed for NCL script)
#ifdef _NETCDF
  call cvmix_io_open(fid, "data.nc", "nc")
#else
  call cvmix_io_open(fid, "data.out", "ascii")
#endif

  call cvmix_output_write(fid, CVmix_vars, (/"Ri   ", "Tdiff"/))
#ifdef _NETCDF
  call cvmix_output_write_att(fid, "long_name", "Richardson number",          &
                              var_name="ShearRichardson")
  call cvmix_output_write_att(fid, "units", "unitless",                       &
                              var_name="ShearRichardson")
  call cvmix_output_write_att(fid, "long_name", "tracer diffusivity",         &
                              var_name="Tdiff")
  call cvmix_output_write_att(fid, "units", "m^2/s", var_name="Tdiff")
#endif
  call cvmix_io_close(fid)

!EOC

End Subroutine cvmix_shear_driver
