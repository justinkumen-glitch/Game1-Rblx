--!strict
-- Game1: the one server-only analytics wrapper. Every call is in pcall.
-- LihFolk notes: Analytics and Funnels; Measuring Onboarding - Funnels, Drop-off and A-B Tests.

local AnalyticsService = game:GetService("AnalyticsService")

local Analytics = {}

-- Never rename or reorder these once live: it breaks the funnel history.
Analytics.ONBOARDING = {
	"Joined",
	"SpeciesChosen",
	"TutorialRaidStarted",
	"FirstConquest",
	"FirstUpgrade",
	"FirstScout",
	"FirstTravel",
	"TutorialDone",
}

-- Logs an onboarding step once per player. `data` is the player's Game1 slice;
-- the caller must MarkDirty the profile afterwards.
function Analytics.Onboarding(player: Player, data: { [string]: any }, stepName: string): boolean
	local step = table.find(Analytics.ONBOARDING, stepName)
	if not step or (data.OnboardingStep or 0) >= step then
		return false
	end
	data.OnboardingStep = step
	pcall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, stepName)
	end)
	return true
end

function Analytics.Economy(player: Player, isSource: boolean, currency: string, amount: number, balance: number, txType: string, sku: string?)
	pcall(function()
		local flow = if isSource then Enum.AnalyticsEconomyFlowType.Source else Enum.AnalyticsEconomyFlowType.Sink
		AnalyticsService:LogEconomyEvent(player, flow, currency, amount, balance, txType, sku or "")
	end)
end

-- Custom events use fixed, small value sets only (never user ids or free text).
function Analytics.Custom(player: Player, eventName: string, value: number?, field1: string?)
	pcall(function()
		local fields = nil
		if field1 then
			fields = { [Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = field1 }
		end
		AnalyticsService:LogCustomEvent(player, eventName, value or 1, fields)
	end)
end

return Analytics
