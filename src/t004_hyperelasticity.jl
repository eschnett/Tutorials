# # Tutorial 4: Hyperelasticity
#
#md # [![](https://mybinder.org/badge_logo.svg)](@__BINDER_ROOT_URL__/notebooks/t004_hyperelasticity.ipynb)
#md # [![](https://img.shields.io/badge/show-nbviewer-579ACA.svg)](@__NBVIEWER_ROOT_URL__/notebooks/t004_hyperelasticity.ipynb)
# 
# ## Problem statement

using Gridap
using LinearAlgebra #TODO tr
using LineSearches

# Material parameters
const λ = 100.0
const μ = 1.0

# Deformation Gradient
F(∇u) = one(∇u) + ∇u'

J(F) = sqrt(det(C(F)))

#Green strain

#E(F) = 0.5*( F'*F - one(F) )

@law dE(x,∇du,∇u) = 0.5*( ∇du*F(∇u) + (∇du*F(∇u))' )

# Right Cauchy-green deformation tensor

C(F) = (F')*F

# Constitutive law (Neo hookean)

@law function S(x,∇u)
  Cinv = inv(C(F(∇u)))
  μ*(one(∇u)-Cinv) + λ*log(J(F(∇u)))*Cinv
end

@law function dS(x,∇du,∇u)
  Cinv = inv(C(F(∇u)))
  _dE = dE(x,∇du,∇u)
  λ*inner(Cinv,_dE)*Cinv + 2*(μ-λ*log(J(F(∇u))))*Cinv*_dE*(Cinv')
end

# Cauchy stress tensor

@law σ(x,∇u) = (1.0/J(F(∇u)))*F(∇u)*S(x,∇u)*(F(∇u))'

# Weak form

res(u,v) = inner( dE(∇(v),∇(u)) , S(∇(u)) )

jac_mat(u,v,du) = inner( dE(∇(v),∇(u)), dS(∇(du),∇(u)) )

jac_geo(u,v,du) = inner( ∇(v), S(∇(u))*∇(du) )

jac(u,v,du) = jac_mat(u,v,du) + jac_geo(u,v,du)

# Model
model = CartesianDiscreteModel(
  domain=(0.0,1.0,0.0,1.0), partition=(20,20))

#model = CartesianDiscreteModel(
#  domain=(0.0,1.0,0.0,1.0,0.0,1.0), partition=(20,10,10))

writevtk(model,"model")

# Construct the FEspace
order = 1
diritags = [1,3,7,2,4,8] # TODO
#diritags = [1,3,5,7,13,15,17,19,25,2,4,6,8,14,16,18,20,26] # TODO
T = VectorValue{2,Float64}
fespace = CLagrangianFESpace(T,model,order,diritags)
V = TestFESpace(fespace)


# Setup integration
trian = Triangulation(model)
quad = CellQuadrature(trian,order=2)

function run(x0,disp_x,step,nsteps)

  g0(x) = zero(T)
  g1(x) = VectorValue(disp_x,0.0) #TODO
  #g1(x) = VectorValue(disp_x,0.0,0.0) #TODO
  U = TrialFESpace(fespace,[g0,g0,g0,g1,g1,g1]) #TODO
  #U = TrialFESpace(fespace,[g0,g0,g0,g0,g0,g0,g0,g0,g0,g1,g1,g1,g1,g1,g1,g1,g1,g1]) #TODO

  #FE problem
  t_Ω = NonLinearFETerm(res,jac,trian,quad)
  op = NonLinearFEOperator(V,U,t_Ω)

  nls = JuliaNLSolver(
    show_trace=true,
    method=:newton,
    linesearch=BackTracking())

  solver = NonLinearFESolver(nls)
  
  
  println()
  println("+++ Solving for disp_x $disp_x in step $step of $nsteps +++")
  println()
  
  uh = FEFunction(U,x0)

  solve!(uh,solver,op)
  
  writevtk(trian,"results_$(lpad(step,3,'0'))",cellfields=["uh"=>uh,"sigma"=>σ(∇(uh))])

  return free_dofs(uh)

end

function runs()

 disp_max = 0.75
 disp_inc = 0.02
 nsteps = ceil(Int,abs(disp_max)/disp_inc)
 
 x0 = zeros(Float64,num_free_dofs(fespace))

 for step in 1:nsteps
   disp_x = step * disp_max / nsteps
   x0 = run(x0,disp_x,step,nsteps)
 end

end

#Do the work!
runs()
