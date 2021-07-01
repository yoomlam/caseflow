# frozen_string_literal: true

class ClaimantsController < ApplicationController
  def refresh_claimant_poa
    poa = BgsPowerOfAttorney.find_by(claimant_participant_id: params[:participant_id])
    # Because `update_cached_attributes!` is in a before save hook for BGSPowerOfAttorney, the below code
    # updates the poa before saving it
    poa&.save!
    render json: { poa: poa }
  end
end
