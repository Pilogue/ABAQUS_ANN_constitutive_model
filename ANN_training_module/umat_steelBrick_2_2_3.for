!****************************************!
!   Abaqus UMAT neural network interface !
!   specific for 2D shell element        !
!   created by Tom Gulikers, TU Delft    !
!   Date: 01-Okt-2018                    !
!                                        !
!****************************************!
! force free-form Fortran 
 !DIR$ FREEFORM

!------ include external modules --------------------------
 include 'globals/parameter_module.f90' 
!------------------------------------------------------

SUBROUTINE UMAT(STRESS, STATEV, DDSDDE, SSE, SPD, SCD, RPL,&
 &DDSDDT, DRPLDE, DRPLDT, STRAN, DSTRAN, TIME, DTIME, TEMP, DTEMP,&
 &PREDEF, DPRED, CMNAME, NDI, NSHR, NTENS, NSTATV, PROPS, NPROPS,&
 &COORDS, DROT, PNEWDT, CELENT, DFGRD0, DFGRD1, NOEL, NPT, LAYER,&
 &KSPT, KSTEP, KINC)

  ! load FNM modules
  use parameter_module,       only: NDIM, DP, ZERO, ONE, SMALLNUM

  include 'aba_param.inc'

  CHARACTER(len=8) :: CMNAME

  ! assign dimension to subroutine variables
  DIMENSION STRESS(NTENS), STATEV(NSTATV), DDSDDE(NTENS, NTENS),  DDSDDT(NTENS), DRPLDE(NTENS), STRAN(NTENS), DSTRAN(NTENS),  PRED&
&EF(1), DPRED(1), PROPS(NPROPS), COORDS(3), DROT(3, 3),  DFGRD0(3, 3), DFGRD1(3, 3)

! initialize algorithm variables
  ! fixed variables: S_sigma, S_epsilon, beta, NB, NC, ND, NE, w_BA, w_CB, w_DC, w_ED, w_FE 
  ! state dependent variables: sigma_NN_i1, B, C, D, E
  integer                                  :: i, j, k, l, NB, NC, n_dim
  real(DP)                                 :: S_sigma, S_epsilon, S_dsigma, S_depsilon
  real(DP), dimension (3)                 :: sigma
  real(DP), dimension (3, 1)              :: sigma_NN_i1, sigma_out
  real(DP), dimension (3, 3)             :: Dmat, Dmatrx
  real(DP), dimension (10, 1)              :: B, b_BA
  real(DP), dimension (2, 1)              :: C, b_final
  real(DP), dimension (6, 1)              :: network_input
  real(DP), dimension (10, 6)             :: w_BA
  real(DP), dimension (2, 10)             :: w_final
  real(DP), dimension (:,:), allocatable   :: w_CB, b_CB, w_DC, b_DC, w_ED, b_ED
  real(DP), dimension (:,:), allocatable   :: D, E, x, net_input, output

  ! fixed variable assignment
  CMNAME = "steelBrick_2_2_3"
  n_dim = 3
  S_sigma = 500.0
  S_epsilon = 0.17
  S_dsigma = 15.0
  S_depsilon = 0.005
  NB = 10
  NC = 10
  ! state dependent variable assignment
  do i = 1, n_dim
    network_input(i,1) = STRESS(i)/S_sigma
    network_input(i+n_dim,1) = STRAN(i)/S_epsilon
    network_input(i+n_dim*2,1) = DSTRAN(i)/S_depsilon
  end do

  ! ---------------------------
  ! Weight and bias definitions
  ! ---------------------------

  ! define weights of HL1
  w_BA(1,:) = (/0.2894326,-0.0773011,-0.68146557,1.1252626,-0.4001652,0.43769097/)
  w_BA(2,:) = (/0.27919528,-0.07341789,2.8693964,-2.6982484,-0.5000227,0.32967353/)
  w_BA(3,:) = (/0.49836028,0.04133112,0.24161868,-0.05285539,-0.50998586,-0.18351519/)
  w_BA(4,:) = (/0.11613608,-0.5329126,-0.2520211,-0.17279837,0.09089571,-0.10012887/)
  w_BA(5,:) = (/0.22701953,-0.7588811,0.02429216,0.08754906,0.11440996,0.21687336/)
  w_BA(6,:) = (/0.4389343,-0.05526435,-1.1248986,0.34933528,0.15004055,-0.73062015/)
  w_BA(7,:) = (/-0.21814364,0.19202669,5.7113557,-3.6689744,-0.01248173,0.2662007/)
  w_BA(8,:) = (/-0.25564992,0.10385158,-0.4789456,1.3049735,0.00437635,0.35279527/)
  w_BA(9,:) = (/-0.41068622,0.53179,-0.8541081,0.2833246,-0.34801894,0.4070937/)
  w_BA(10,:) = (/0.01717847,0.03996803,-1.2073258,1.0404825,0.5645091,-0.35409203/)

  ! define biases of HL1
  b_BA(:,1) = (/-0.01463276,0.05080077,-0.02707054,-0.01848457,-0.01177356,-0.05440606,-0.04005689,-0.01494109,-0.19396451,0.01621&
&661/)

  allocate ( w_CB(10,10) )
  w_CB(1,:) = (/-0.6890028,-0.09365311,-0.40814233,0.34364247,-0.54977256,-0.4234655,-0.02598912,-0.07167953,-0.03107655,-0.166131&
&14/)
  w_CB(2,:) = (/-0.08130009,0.3189997,0.467601,0.12746182,-0.5423511,-0.301621,-0.2551392,0.7063144,-0.17473866,0.47801688/)
  w_CB(3,:) = (/0.02376772,-0.48562104,-0.1781824,-0.12967996,-0.6683323,-0.3298029,-0.07224097,-0.25973034,-0.02309041,-0.3678307&
&5/)
  w_CB(4,:) = (/0.6205939,-0.7916617,-0.41595605,0.6266705,0.07232471,0.13544968,-0.6565436,-0.02120195,0.6217376,-1.2959572/)
  w_CB(5,:) = (/-0.0086981,0.16218834,0.20899881,0.27360114,0.01113379,-0.3861806,0.39750406,0.06330932,-0.13822159,0.13328221/)
  w_CB(6,:) = (/-0.05143739,0.077513,-0.01903085,-0.04862683,0.05004748,0.20777623,0.01350325,-0.04672958,0.14054619,0.04976306/)
&
&  w_CB(7,:) = (/0.28831592,0.20434637,0.29354367,0.39165992,-1.6633761,-0.22083576,-0.27363604,-0.5529,0.1047247,-0.38588324/)
  w_CB(8,:) = (/0.5260751,-1.0039742,0.17090596,0.33775637,-0.33039883,-0.8654426,-1.6695231,0.69937974,0.9278363,-1.1091051/)
  w_CB(9,:) = (/-0.43269598,0.2635929,-0.6227324,0.09811074,-0.12003553,0.45966026,-0.69405603,-0.68678135,0.5231404,0.20276268/)
&
&  w_CB(10,:) = (/0.25599578,-0.119141,-0.12976377,0.66155446,-0.08142596,0.3789159,-0.07112476,-0.07264732,-0.15592967,-0.00551949&
&/)
  allocate ( b_CB(10,1) )
  b_CB(:, 1) = (/-0.11067538,-0.1560468,-0.03878863,-0.00869937,-0.05267307,0.03681167,-0.04361706,-0.0195149,-0.06433079,-0.02074&
&544/)

  ! define weights of output layer
  w_final(1,:) = (/-0.11608349,0.01390572,0.19481303,-0.7583406,0.04460613,-0.29587492,0.16455147,-0.5998071,-0.60832703,0.0493863&
&6/)
  w_final(2,:) = (/0.01586339,0.03499016,-0.05234232,0.8047084,0.08868967,0.06250589,-0.08009509,0.60164255,0.03464114,0.06051506/&
&)

  ! define bias of output layer
  b_final(:,1) = (/0.0103084,0.00170968/)

  ! ---------------------------
  ! Neural network calculations
  ! ---------------------------

  ! HL_1 assignment of variables
  allocate ( x (6, 1))        ! neuron input
  allocate ( net_input(10, 1)) ! shape same as w_BA.shape[0]
  allocate ( output(10, 1))    ! shape same as w_BA.shape[0]

  ! HL_1 calculation
  x = network_input
  net_input = matmul(w_BA,x) + b_BA
  output = max(net_input,ZERO)   ! ReLu function
  B = output

  ! second hidden layer calculation
  deallocate ( net_input)
  deallocate (x)

  ! HL_2 assignment of variables
  allocate ( x(10, 1))          ! shape same as w_CB.shape[1]
  allocate ( net_input(10, 1))  ! shape same as w_CB.shape[0]
  x = output
  deallocate (output)
  allocate ( output(10, 1))     ! shape same as w_CB.shape[0]

  ! HL_2 calculation
  net_input = matmul(w_CB, x) + b_CB
  output = max(net_input,ZERO)    ! ReLu function
  C = output
  deallocate(w_CB)
  deallocate(b_CB)

  ! output layer assignment of variables
  deallocate (net_input)
  deallocate (x)
  allocate ( x(10, 1))             ! shape same as w_final.shape[0]
  allocate ( net_input(2, 1))     ! shape same as w_final.shape[1]
  x = output
  deallocate (output)
  allocate ( output(2, 1))        ! shape same as w_final.shape[1]

  ! output layer calculation
  net_input = matmul(w_final, x) + b_final
  output = tanh(net_input)
  sigma_NN_i1 = output

  ! deallocate all temporary variables
  deallocate(output)
  deallocate(x)
  deallocate(net_input)

  ! -----------------------------------
  ! secant stiffness matrix calculation
  ! -----------------------------------
  do i = 1, n_dim
    do j = 1, n_dim
      if (abs(stran(j)+dstran(j))<SMALLNUM) then
      Dmat(i, j) = stress(i) / SMALLNUM   ! 100._dp
      else
      Dmat(i, j) = stress(i) / stran(j)
      end if
    end do
  end do
  ! ---------------------------------------------
  ! Pass internal variables to subroutine outputs
  ! ---------------------------------------------
   DDSDDE   = Dmat
   STRESS   = STRESS + sigma_NN_i1(:,1)*S_dsigma

end subroutine umat
